# Cloud-nativer Service-Marktplatz auf Kubernetes: Konzept und Architektur

## 📋 Inhaltsverzeichnis

1. [Einführung und Ziele](#einführung-und-ziele)
2. [Architektur des Marktplatzes](#architektur-des-marktplatzes)
3. [Self-Service Interfaces](#self-service-interfaces)
4. [Sicherheit, Isolation und Governance](#sicherheit-isolation-und-governance)
5. [Risiken und Herausforderungen](#risiken-und-herausforderungen)
6. [Alternativen und Vergleich](#alternativen-und-vergleich)
7. [Fazit](#fazit)

## 🎯 Einführung und Ziele

Ein interner Cloud-Marktplatz soll es Entwicklern (interne Kunden) ermöglichen, komplexe Services selbst per Self-Service zu bestellen, ohne sich um die technischen Details der Infrastruktur kümmern zu müssen. Alles soll cloud-native umgesetzt werden – im Kern auf Kubernetes basiert. Sogar externe Ressourcen wie DNS-Einträge oder Firewall-Regeln werden als Custom Resources (CRDs) in Kubernetes modelliert und verwaltet. Die Vision ist im Grunde eine Internal Developer Platform (IDP): Entwickler ordern per API, CLI oder Web-UI einen Service, und im Hintergrund werden alle benötigten Komponenten und Infrastruktur automatisch bereitgestellt ￼. Dies erhöht die Autonomie der Entwickler und entlastet zentrale Teams, da keine manuellen Bereitstellungsprozesse mehr nötig sind.

## 🏗️ Architektur des Marktplatzes

### Technologie-Stack
- **Kubernetes** + **Crossplane** + **GitOps**

### Kubernetes als Control-Plane 
Der Marktplatz basiert auf einem Kubernetes-Cluster, der als zentrales Control-Plane für alle Services dient. Jeder Service wird durch einen Kubernetes Custom Resource (CR) repräsentiert. Dank Crossplane – einem Open-Source-Projekt zur infrastrukturellen Erweiterung von Kubernetes – können wir Cloud-Ressourcen und sogar nicht-Kubernetes-Komponenten als CRDs definieren und verwalten ￼. Crossplane installiert dafür sogenannte Provider-Controller für verschiedene Cloud- und Infrastruktur-APIs und ermöglicht es, diese externen Ressourcen deklarativ über Kubernetes zu steuern ￼ ￼.

### Alles als CRD

Für jeden angebotenen Service (egal ob „komplexer“ Service wie eine Data-Science-Plattform oder „Komponenten“-Service wie eine PostgreSQL-Datenbank) wird ein eigener CRD-Typ definiert. Sogar Infrastruktur-Bausteine wie DNS-Einträge, Zertifikate oder Firewall-Regeln werden über Crossplane-Provider in Kubernetes abgebildet, so dass sämtliche Bausteine im Marktplatz über die Kubernetes-API verwaltet werden können. Dieses API-zentrierte Modell vermeidet Medienbrüche: Entwickler interagieren ausschließlich mit Kubernetes-Objekten, nicht mit separaten Cloud-Konsolen oder Skripten ￼ ￼. Zugangsdaten zu Cloud-Providern liegen nur bei Crossplane selbst (etwa als ProviderConfig mit hinterlegtem Secret), sodass Entwickler keine Cloud-Zugangsdaten benötigen und Berechtigungen zentral in Kubernetes verwaltet werden ￼ ￼.

### Crossplane Compositions – Abstraktion für Service-Owner

Ein zentrales Konzept ist die Abstraktion durch Crossplane-Compositions. Jeder Service-Typ erhält eine benutzerfreundliche Oberflächen-API (Custom Resource Definition), deren Spec nur die nötigsten Eingabeparameter enthält. Die Details der Umsetzung werden in einer Composition hinterlegt, die festlegt, welche konkreten Ressourcen im Hintergrund angelegt werden. Dadurch können komplizierte Setups in höherwertige Ressourcen abstrahiert werden ￼ ￼. Zum Beispiel kann es einen CRD-Typ PostgreSQLInstance geben, bei dem der Nutzer nur Parameter wie Datenbank-Größe und Version angibt – Dinge wie VM-Instanzgröße, Netzwerk oder Backup-Einstellungen sind in der Composition fest codiert durch den Service-Owner (Platform-Team) und für den Nutzer nicht sichtbar ￼. Crossplane kümmert sich dann darum, beim Anlegen eines solchen CR alle erforderlichen Cloud-Ressourcen zu erzeugen (z.B. eine AWS RDS Instanz oder eine Azure PostgreSQL DB), ggf. inkl. ergänzender Ressourcen wie Subnetzen, DNS-Records oder IAM-Usern ￼ ￼. Für den Entwickler sieht das aus wie eine einzige Ressource in Kubernetes, die er erstellt – die komplexen Details sind durch die Composition vor ihm verborgen ￼. Dieses Prinzip lässt sich auch verschachteln: Eine Composition kann mehrere unterliegende Ressourcen anlegen – beispielsweise könnte die Bereitstellung einer AI-Data-Science-Plattform gleichzeitig eine PostgreSQL-Datenbank, einen S3-Speicher und einen Kafka-Cluster anlegen, indem die Composition intern die entsprechenden Component-Services als CRs erzeugt.

### Service Owner und Schichtung der Services

Daraus ergibt sich ein mehrstufiges Modell von Services mit jeweils eigenen Verantwortlichen (Service Owner):

#### 1️⃣ Infrastruktur-Services

Beispiele: „Kubernetes-Cluster“, „DNS-Eintrag“, „TLS-Zertifikat“, „Firewall-Regel“. Diese werden meist vom zentralen Platform-Team bereitgestellt. Sie bilden die unterste Schicht und laufen oft als Crossplane-Managed Resources direkt auf Cloud-APIs (z.B. DNS via Route53, Cluster via EKS/AKS, etc.).

#### 2️⃣ Komponenten-Services

Wiederverwendbare technische Dienste wie PostgreSQL, MongoDB, Kafka, S3-Storage usw. Diese haben eigene Service Owner (Datenbank-Team, Messaging-Team, …), die Experten für ihren Dienst sind. Sie nutzen die Infrastruktur-Services als Bausteine: Beispielsweise könnte der PostgreSQL-Service einen Kubernetes-Cluster oder eine VM benötigen, auf der die DB läuft, einen persistenten Storage und evtl. einen DNS-Eintrag für die DB-URL. All das bindet der DB-Service-Owner über Crossplane ein, ohne die Details dieser Infrastruktur selbst manuell zu betreiben – er deklariert nur in seiner Composition, dass z.B. ein DNSRecord-CR für die DB angelegt werden soll, und verlässt sich darauf, dass der DNS-Service-Owner dafür gesorgt hat, dass DNSRecord-CRDs funktionieren. So kann jeder Komponenten-Service seine Abhängigkeiten als weitere CRs modellieren, die wiederum von anderen Ownern geliefert werden.

#### 3️⃣ Komplexe Services

Das sind die Angebote, die der Endnutzer (Entwickler) letztlich bestellt, z.B. eine AI Data Science Plattform oder allgemein eine Entwicklungsumgebung, ein Jenkins-as-a-Service etc. Diese bestehen intern aus mehreren Komponenten-Services, werden aber als ein Produkt angeboten. Der Service-Owner eines komplexen Services definiert dessen CRD und Composition so, dass beim Anlegen z.B. einer AIPlatform-Resource automatisch alle benötigten Komponenten (Postgres, Kafka, … siehe oben) in Anspruch genommen werden. Wichtiges Akzeptanzkriterium ist hier: Der komplexe Service-Owner soll möglichst nichts über die Implementation der Komponenten-Services wissen müssen. Er gibt in der Composition z.B. nur an „für diese AIPlatform eine PostgreSQL-Instanz anlegen“ (durch Erzeugen eines PostgreSQLInstance-CRs mit bestimmten Parametern). Wie genau der DB-Service diese Instanz bereitstellt, bleibt gekapselt in dessen Composition. Analog muss der Komponenten-Service-Owner (z.B. für PostgreSQL) die Infrastruktur darunter nicht im Detail kennen; er fordert z.B. über einen Cluster-CR oder Speichervolumen-CR Infrastruktur an, ohne selbst direkt VMs zu konfigurieren – diese Details stecken wiederum in den Infra-Service Compositions. Jeder kümmert sich also nur um seine Abstraktion.

Durch diese Schichtung und Crossplane bleibt die Komplexität in den unteren Schichten (Plattform-Team), während die oberen Schichten einfache Interfaces haben ￼. Entwickler können so komplexe Anwendungen ordern, ohne von den zig Abhängigkeiten dahinter zu wissen – „Everything as a Service“ innerhalb der Firma. Beim Bestellen der AI-Plattform etwa reicht ein CR anlegen; Crossplane erstellt daraus die DB, den Kafka, alle nötigen Infrastrukturobjekte und natürlich den AI-Plattform-Dienst selbst, komplett automatisiert.

### Deployment der Services via GitOps

Die Service-Definitionen (CRDs, Compositions, etc.) leben in Git-Repositories – pro Service gibt es z.B. ein eigenes GitHub-Repo mit seinen YAML-Definitionen. Ein GitOps-Werkzeug wie Flux oder Argo CD synchronisiert diese kontinuierlich ins Cluster. Das heißt, wenn ein Service-Owner sein Angebot weiterentwickelt (neue Version der Composition, neue CRD-Felder, etc.), reicht ein Commit und der GitOps-Operator wendet die Änderungen im Kubernetes-Cluster an. So ist das Control-Plane-Cluster immer auf dem aktuellen Stand der gewünschten Service-Katalog-Definitionen. Dies vereinfacht Updates und Versionierung enorm, da alle Änderungen nachvollziehbar in Git historisiert sind.

**Beispiel**: Der Owner des PostgreSQL-Service pflegt in seinem Git-Repo die Crossplane-Composition, die einen AWS RDS-Postgres erstellt. Flux synchronisiert die CRD & Composition ins Cluster. Wenn er eine Optimierung vornimmt (z.B. anderen Instance-Typ oder Backup-Policy), committet er die Änderung; Flux updatet die Composition. Neue Bestellungen nutzen dann automatisch die aktualisierte Definition.

```yaml
# Beispiel einer vereinfachten PostgreSQL Composition
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgresql-aws
spec:
  compositeTypeRef:
    apiVersion: database.company.io/v1alpha1
    kind: PostgreSQLInstance
  resources:
    - name: rds-instance
      base:
        apiVersion: rds.aws.crossplane.io/v1alpha1
        kind: DBInstance
        spec:
          forProvider:
            region: eu-central-1
            engine: postgres
            engineVersion: "14"
            dbInstanceClass: db.t3.micro
            allocatedStorage: 20
```

Im Prototyp kann hierfür jedes Managed-Kubernetes verwendet werden (z.B. ein Cluster in einer Umgebung wie Spot by NetApp oder Rackspace – wichtig ist nur, dass Crossplane + GitOps darauf laufen können). Für die Produktivumgebung würde man dann das Unternehmens-Cluster (oder Managed K8s in der Cloud) nutzen. Die Plattform ist prinzipiell Cloud-agnostisch, solange Crossplane-Provider für die genutzten Cloud-Dienste verfügbar sind (AWS, Azure, GCP und viele weitere werden unterstützt).

## 🖥️ Self-Service Interfaces

### Übersicht

Entwickler sollen die Services auf verschiedene Weisen bestellen können:

#### 1. Kubernetes CLI/API (kubectl)

Da alles über Kubernetes-Objekte läuft, kann ein versierter Nutzer einfach per kubectl apply -f myservice.yaml den gewünschten CR im Cluster erstellen. Das ist die direkteste Methode (bzw. via CI/CD Pipeline). Ebenso kann der Terraform Kubernetes Provider verwendet werden – dieser ermöglicht es, Kubernetes-Ressourcen (also unsere Service-CRs) in Terraform-Manifeste einzubinden und so bereitzustellen. In beiden Fällen spricht der Nutzer letztlich die Kubernetes-API an.

#### 2. Web-Frontend (Backstage)

Für eine komfortable Bestelloberfläche setzen wir auf Backstage als Developer-Portal. Backstage präsentiert den Katalog der verfügbaren Services und ermöglicht es, über Formular-Eingaben einen Service zu provisionieren. Hierzu integrieren wir Backstage eng mit unserem Kubernetes-GitOps-Flow:

##### Katalogintegration

Jede Service-Art (CRD) soll im Backstage-Katalog auftauchen, idealerweise ohne viel manuelle Pflege. Backstage bietet dafür ein Kubernetes Ingestor-Plugin, das automatisch im Kubernetes-Cluster nach bestimmten Ressourcen sucht und sie als Components in den Catalog importiert ￼ ￼. Insbesondere kann es Crossplane-Claims und -CRDs automatisch ingestieren: d.h. unsere angebotenen Service-CRDs erscheinen als Template oder Component in Backstage, ohne dass wir für jeden eine catalog-info.yaml von Hand schreiben müssen ￼. Durch Annotationen an den CRDs/Resources lässt sich steuern, wie sie im Catalog dargestellt werden ￼ ￼. Dies erspart viel manuelle Pflege, da der Katalog sich direkt aus der Kubernetes-Realität speist.

##### Bestellvorgang über GitOps

Im einfachsten Fall könnte Backstage direkt einen API-Call ans Cluster machen, um einen neuen CR zu erzeugen (über ein Backend-Plugin mit ServiceAccount). Besser ist jedoch eine GitOps-Integration: Das TeraSky Crossplane-Plugin für Backstage ermöglicht, dass ein Bestellvorgang einen Pull Request in einem Git-Repo erzeugt, der den gewünschten Custom Resource enthält ￼. Dieser PR kann geprüft und gemergt werden, woraufhin Flux/ArgoCD den neuen CR im Cluster anlegt. Dieses Vorgehen hält alle Änderungen unter Versionskontrolle und passt zu einem deklarativen Workflow (selbst Service-Bestellungen werden als Code erfasst). Für den Prototyp kann man es aber auch zunächst pragmatisch halten (KISS-Prinzip) und Bestellungen direkt durchführen, während man die GitOps-Anbindung später verfeinert.

##### Visualisierung

Backstage dient nicht nur zur Bestellung, sondern auch zur Übersicht und zum Status der laufenden Services. Über das Crossplane-Resources-Plugin können wir auf der UI die Details eines bestellten Service-Instances einsehen – inklusive der unterliegenden Ressourcen und sogar einer Graph-Visualisierung der Abhängigkeiten ￼ ￼. So kann ein Entwickler in Backstage z.B. sehen, dass seine AI-Plattform X eine PostgreSQL-DB Y und einen Bucket Z beinhaltet, und ob all diese gesund sind. Es gibt auch eine Übersichtskarte pro Service-Component mit Status-Infos (Running, Fehler, etc.), was die Day-2 Operations erleichtert ￼ ￼.

##### Authentifizierung und Berechtigungen

Backstage integriert sich mit Identity-Providern. Im Prototyp ist geplant, GitHub OAuth für Login zu nutzen (schnelle Einrichtung), während produktiv natürlich die unternehmensweite Microsoft Entra ID (Azure AD) angebunden wird. Rollen und Berechtigungen können dann zentral gesteuert werden (z.B. welche Nutzer dürfen welchen Service ordern). Für den Prototyp steht jedoch Einfachheit im Vordergrund, komplexe RBAC-Policies werden zunächst ausgeklammert (man kann annehmen, dass alle internen Nutzer gleiche Rechte haben im Testsystem).

### 🏗️ Zusammenfassung der Architektur-Komponenten

Die Architektur besteht aus folgenden Hauptkomponenten:

| Komponente | Funktion | Details |
|------------|----------|----------|
| **Kubernetes-Cluster** | Zentrale API-Plattform | Hostet alle CRDs und Control-Plane |
| **Crossplane** | Infrastructure-as-Code | Definiert CRDs für Services, managed Lebenszyklus |
| **GitOps** | Deployment & Sync | Flux/Argo CD synchronisiert Configs und Bestellungen |
| **Backstage** | Developer Portal | UI für Katalog, Bestellung, Status-Dashboards |
| **Identity Provider** | Auth & Access | GitHub (Prototyp) / Azure AD (Produktion) |

Ein solches Zusammenspiel von Backstage als UI, Crossplane als API-Layer und GitOps als Delivery-Mechanismus wird in der Platform-Engineering-Community als Best Practice angesehen ￼ – es liefert alle Bausteine, um eine interne Plattform bereitzustellen, die sowohl benutzerfreundlich (durch Backstage) als auch operationalisiert (durch K8s/Crossplane) ist.

## 🔒 Sicherheit, Isolation und Governance

Bei einem gemeinsamen Kubernetes-Cluster für den Marktplatz ist es wichtig, Multi-Tenancy und Zugriffsrechte sauber zu regeln. Crossplane und Kubernetes bieten hierfür Mechanismen:

### Namespaces und RBAC

Wir planen, pro Team oder Anwendungsfall separate Namespaces zu nutzen. Entwickler erhalten nur Rechte in „ihrem“ Namespace, um dort Service-Instanzen (Claims) anzulegen. Die CustomResourceDefinitions der Services können so gestaltet sein, dass sie namespaced Claims unterstützen – d.h. der Entwickler legt z.B. ein DatabaseClaim in seinem Namespace an, während Crossplane im Hintergrund eine clusterweite Ressource XDatabase verwaltet ￼ ￼. Über RBAC kann man Rechte vergeben wie „Gruppe DataScientists darf im Namespace team-ds Objekte vom Typ AIPlatform (oder deren Claim) erstellen“. Aber sie dürfen z.B. nicht direkt die low-level Infrastruktur-CRDs anlegen. So exponiert man nur die abstrahierten APIs auf Namespace-Ebene und schützt die darunterliegenden Details ￼.

### Isolation der Provider Credentials

Crossplane erlaubt es, pro Namespace unterschiedliche Cloud-Credentials zu nutzen, indem die Composition das spec.providerConfigRef je nach Namespace patchen kann ￼. In unserem Kontext ist das ggf. relevant, falls verschiedene Projekte verschiedene Cloud-Accounts nutzen sollen. Im einfachsten Fall nutzen aber alle denselben Account, dann reicht eine globale Konfiguration (die ProviderConfig liegt im crossplane-system Namespace und wird von allen genutzt). Wichtig ist, dass Entwickler die Credentials nie direkt sehen – nur Crossplane hat Zugriff, was ein Sicherheitsgewinn ist ￼.

### Policy Enforcement

In einer produktiven Plattform möchte man Richtlinien durchsetzen, z.B. dass niemand eine DB größer als X GB ordert oder dass gewisse Tags gesetzt werden. Hierfür lassen sich Admission Controller/Policy Engines wie Kyverno oder OPA Gatekeeper einsetzen. Crossplane selbst bietet in Compositions schon Möglichkeiten, Default-Werte zu setzen oder Eingaben zu validieren (via OpenAPI-Schema) ￼ ￼. Darüber hinaus könnten übergreifende Policies mit Tools wie Kyverno kontrolliert werden – das Backstage-Plugin unterstützt z.B. das Visualisieren von Kyverno Policy Reports direkt im UI ￼ ￼. Im Prototyp werden wir Policies eher minimal halten (KISS), aber für den produktiven Betrieb ist dies ein wichtiger Aspekt (Governance).

### Trennung der Verantwortlichkeiten

Die oben beschriebene Service-Owner-Struktur bringt bereits eine gewisse Trennung mit sich. Jeder Service-Owner (z.B. Postgres-Team) entwickelt seine Composition und hat Schreibrechte darauf, aber ein anderer Service-Owner nicht. Man kann dies über Git-Repos und CI/CD erzwingen (jeder Merge in die zentralen Configs geht über Code Review durch das jeweilige Team). Innerhalb Kubernetes könnte man Crossplane in verschiedenen Scoping-Modi betreiben – z.B. theoretisch mehrere Crossplane-Instanzen in unterschiedlichen Namespaces für verschiedene Teams (für unseren Use-Case vermutlich nicht nötig, da Crossplane zentral okay ist). Entscheidend ist: Nur vertrauenswürdige Admins dürfen neue CRD-Typen (XRDs/Compositions) installieren; normale Dev-User dürfen nur Instances/Claims erstellen. So bleibt die Kontrolle über das „Angebotsportfolio“ beim Plattform-Team.

### Authentifizierung und Auditing

Mit Azure AD als IdP wird sichergestellt, dass nur authentifizierte Mitarbeiter Zugriff haben. Jede Aktion (z.B. CR anlegen/löschen) ist eine Kubernetes-API-Operation und somit im Audit-Log verfolgbar. Zudem pflegt GitOps ein Audit-Trail über alle Änderungen (Commits, PRs), was Revisionen nachvollziehbar macht.

### Abgrenzung Umgebungen

Möglicherweise trennt man Prototyp / Entwicklung von Produktion über eigene Cluster oder zumindest Namespaces. Im Prototyp-Cluster kann mit Dummy-Services frei getestet werden. Später könnte man Produktiv-Services auf einem dedizierten Crossplane-Cluster laufen lassen, der die echten Cloud-Ressourcen verwaltet, während Entwickler ggf. in separaten Clustern arbeiten. Crossplane unterstützt sogar Multi-Cluster Szenarien (Control-Plane of Control-Planes), falls man beispielsweise die Service-CRDs zentral definieren, aber in mehreren Ziel-Clustern ausrollen will ￼ ￼ – etwa um verschiedene Regionen oder Staging/Prod zu bedienen. Diese Komplexität ist vorerst nicht nötig, aber skalierbar.

### Secret-Management

Viele Services liefern Zugangsdaten (DB Credentials, API Keys). Crossplane legt solche Connection Secrets standardmäßig in einem Namespace (z.B. crossplane-system) ab ￼ ￼. Man muss entscheiden, wie diese den Endnutzern zugänglich gemacht werden. Evtl. kopiert die Composition das Secret in den Namespace des Bestellers (Crossplane kann ConnectionDetails aus der Composition an übergeordnete CRs propagieren ￼). Alternativ kann Backstage die Secrets auslesen und dem Nutzer anzeigen oder in ein Vault integrieren. Wichtig ist, hier keine Sicherheitslücken zu haben (Zugriff nur für berechtigte Nutzer auf ihre eigenen Secrets).

Zusammengefasst minimieren wir Risiken, indem wir strikte RBAC-Regeln, klar abgegrenzte Namespaces und prüfbare Workflows (GitOps, CodeReviews) einsetzen. Damit bleibt das Selbstbedienungs-Portal kontrolliert und sicher, trotz hoher Autonomie für die Entwickler.

## ⚠️ Risiken und Herausforderungen

Trotz des vielversprechenden Konzepts gibt es einige Herausforderungen und Risiken zu beachten:
### 📈 Steile Lernkurve & Kulturwandel
 Die Einführung von Crossplane und dem Konzept „alles als Kubernetes-Objekt“ erfordert Schulung. Service-Owner müssen lernen, Compositions zu schreiben (YAML, Verständnis der Provider-CRDs), Entwickler müssen lernen, mit den abstrahierten CRDs umzugehen. Das ist zwar einfacher als direkt Terraform/Cloud-APIs zu bedienen, aber dennoch neu. Ohne Akzeptanz oder bei unzureichendem Training könnten Benutzer versucht sein, die Plattform zu umgehen.

### 🏗️ Abstraktionsdesign & Wartbarkeit
 Die Qualität der abstrahierten Services steht und fällt mit dem Design der CRD-Schnittstellen. Wählt ein Service-Owner die falschen Parameter (zu viele Details nach oben gereicht, oder zu unflexibel), leidet entweder die Benutzerfreundlichkeit oder die Nutzbarkeit. Es braucht also Guidelines für Service-Owner, was sie ihren Nutzern an Optionen geben und was sie intern fest hinterlegen. Auch müssen Compositions versionierbar sein – Crossplane erlaubt z.B. Composition Revisions, sodass bestehende Instanzen auf alter Version bleiben können, während neue eine aktualisierte Composition nutzen.

### ⚠️ Fehler- und Konfliktbehandlung
 Bei automatisierter Kaskaden-Provisionierung ist das Fehlermanagement kritisch. Beispiel: Ein Data Scientist bestellt die AI-Plattform, dabei soll u.a. eine DB und ein Kafka entstehen. Was passiert, wenn die DB-Provisionierung fehlschlägt (z.B. Cloud-Quota erreicht)? Crossplane wird dies im Status der AIPlatform-Resource vermerken (Events, Conditions). Der Nutzer sieht dann „provisioning failed“. Es muss klar kommuniziert werden, wie in solchen Fällen zu verfahren ist (Retry? Quota erhöhen? Support einschalten?). Die Plattform sollte möglichst transparente Status-Infos liefern (Backstage-Plugin hilft hier, da es den Status jeder Teilressource zeigen kann).

### ⏳ Transiente Inkonsistenzen
 Während einer Bestellung werden Ressourcen sequenziell angelegt. Es kann Zeit dauern (eine DB kann mehrere Minuten brauchen). In dieser Zeit ist der Gesamtservice noch nicht einsatzbereit. Das ist normal, aber Nutzer sollten dies verstehen (z.B. Status „im Aufbau“). Zudem muss Crossplane Abhängigkeiten korrekt behandeln – normalerweise definiert man implizite Abhängigkeiten über das Warten auf bereitgestellte Secrets oder Status der Sub-Ressourcen, was Crossplane erledigt. Dennoch gilt es, die Compositions sorgsam zu testen, damit alle patches & Verknüpfungen stimmen ￼ ￼ (z.B. die DB-URL aus dem RDS-Secret ins AIPlatform-Secret propagieren etc.).

### 🚀 Performance und Skalierbarkeit
 Ein Kubernetes-Operator (Crossplane) hat Limits in Bezug auf wie viele Ressourcen er verwalten kann. Crossplane ist darauf ausgelegt, durchaus Hunderte bis Tausende von CRs zu managen, aber das Team sollte Monitoring einrichten (Prometheus Metrics von Crossplane) um sicherzustellen, dass die Reconciliation Loops performant laufen. In sehr großen Umgebungen könnte eine Aufteilung auf mehrere Crossplane-Instanzen (pro Umgebung oder pro Team) erwogen werden ￼ ￼. Im Prototyp spielt das keine Rolle, aber bei Erfolg muss man die Skalierbarkeit im Auge behalten.

### 🎯 Crossplane Maturity & Provider-Abdeckung
 Crossplane selbst ist CNCF Incubation Project (Stand 2025) und wird rege weiterentwickelt. Viele Unternehmen nutzen es produktiv, aber es bleibt ein komplexes System. Man muss die Updates im Auge behalten. Die Provider (z.B. für AWS, Azure) sollten genau auf ihre Version und Stabilität geprüft werden – nicht jeder Provider ist gleich weit gereift. Für manche Spezialdienste gibt es evtl. (noch) keinen fertigen Provider. In solchen Fällen müsste man Workarounds nutzen (z.B. Crossplane-Provider für Terraform Provider Jet, um eine Terraform-Konfiguration auszuführen, falls Crossplane direkt etwas nicht kann). Diese Lücken gilt es früh zu identifizieren, damit keine bösen Überraschungen auftreten, wenn ein bestimmter Service doch nicht vollständig automatisierbar ist.

### 🔒 Lock-in und Alternativen
 Indirekt begibt man sich auf einen Pfad, der von bestimmten Tools abhängt (Crossplane, ArgoCD, Backstage). Allerdings sind dies Open-Source-Lösungen, die on-premise betrieben werden, also kein klassischer Vendor-Lock-in. Dennoch: Sollte Crossplane sich in Zukunft nicht durchsetzen oder das Unternehmen eine andere Strategie fahren, steht man vor einer Migration der Plattform. Glücklicherweise abstrahiert Crossplane nur auf Kubernetes-Standard – d.h. im Worst Case hat man „nur“ Kubernetes-Manifeste, die man evtl. anders interpretieren muss. Der Marktplatz-Ansatz an sich ist aber unabhängig vom konkreten Tool implementierbar.

### 💰 Ressourcenkosten und Governance
 Self-Service kann zu unkontrolliertem Ressourcenverbrauch führen, wenn keine Leitplanken existieren. Plötzlich hat jeder Entwickler dutzende DB-Instances laufen. Hier müssen wir vorsorgen: z.B. Quotas pro Namespace, Freigabeprozesse für besonders teure Services, oder wenigstens Transparenz über laufende Kosten. Crossplane selbst hat keine eingebaute Kostenkontrolle, aber man könnte etwa ein Billing-Export an Backstage anbinden oder Alerts definieren. Dieses Thema ist organisatorisch zu klären (wer trägt Kosten, Freigaben etc.), gehört aber zu den Risiken.

### ♾️ Lifecycle und Cleanup
 Wenn ein Nutzer einen Service nicht mehr braucht und den CR löscht, sorgt Crossplane dafür, dass alle untergeordneten Ressourcen aufgeräumt werden (inkl. Cloud-Ressourcen). Das ist super für automatisches Cleanup – aber birgt auch Risiko: Daten könnten verloren gehen, wenn versehentlich etwas gelöscht wird. Evtl. möchte man Schutzmechanismen („do not delete prod DB without approval“). Crossplane bietet z.B. sog. DeletionPolicy an manchen Ressourcen (z.B. Retain statt Delete). In Compositions kann man das berücksichtigen. Für den Prototyp reicht der Default (löschen löscht alles), doch produktiv muss man festlegen, welche Services kritische persistent data haben und ggf. eine Grace-Period oder Backup vor Löschen einplanen.

### 🔄 CI/CD für Service-Implementierungen
 Neben der Crossplane-Ebene gibt es ja auch die eigentlichen Service-Komponenten. Z.B. könnte der AI-Plattform-Service aus einer Sammlung von Microservices bestehen, die als Docker-Images vorliegen. Diese müssen gebaut (GitHub Actions) und irgendwo deployt werden (vielleicht als Helm Chart via Crossplane’s Helm-Provider, oder über ArgoCD als Teil der Composition). Wir haben Dummy-Services, aber sobald es real wird, brauchen wir Deployment-Pipelines für die eigentlichen Service-Anwendungen. Dies gehört zur technischen Umsetzung – im Konzept nehmen wir an, dass Service Owner ihre Komponenten containerisieren und versionieren. Der Marktplatz orchestriert dann deren Deployment (z.B. in einem gemeinsamen Cluster oder dedizierten Cluster pro Instanz). Das ist ein weiteres Workstream (Images bauen, registries, etc.), das parallel angegangen werden muss, um die Plattform end-to-end lauffähig zu machen.

### 🎨 Backstage-Integrationsaufwand
 Die erwähnten Backstage-Plugins (Kubernetes Ingestor, Crossplane UI, etc.) stammen aus Open-Source (z.B. von TeraSky) und müssen ins eigene Backstage integriert werden. Das ist zwar machbar, aber erfordert etwas Frontend-/Backend-Arbeit im Backstage-Projekt (Plugins installieren, Konfigurieren gem. Doku ￼ ￼). Man sollte dafür Zeit einplanen. Auch muss Backstage selbst gehostet und gewartet werden (Updates, Plugins pflegen). Als Alternative gäbe es gehostete Backstage (z.B. SaaS von Roadie) – dort sind die Plugins teils schon integriert ￼ ￼. Aber beim Prototyp vermutlich Self-Hosted Backstage im Cluster.

### 🔍 Beobachtbarkeit und Debugging
 Es wurde schon angesprochen, aber nochmal: Wenn etwas schiefgeht, müssen Platform-Teams in der Lage sein, schnell die Ursache zu finden. Crossplane schreibt Events, Logs – man sollte zentral logging/monitoring haben (ELK/ Loki, Prometheus). Auch für Performance-Metriken (Crossplane Reconcile Zeiten, etc.) gibt es Telemetrie. Dies stellt sicher, dass das Platform-Team Probleme beheben kann, bevor Nutzer frustriert aufgeben.

Trotz dieser Herausforderungen überwiegen die Vorteile: Entwicklerzufriedenheit durch Self-Service, konsistente Automatisierung, und klare Verantwortlichkeiten je Service. Viele der Risiken lassen sich durch Policies, Schulung und schrittweises Herantasten (erst Dummy-Services, dann kritische Services) mitigieren.

## 🔄 Alternativen und Vergleich

Das vorgeschlagene Konzept setzt stark auf Kubernetes und Crossplane. Es gibt jedoch alternative Ansätze, die in Betracht gezogen werden können oder bei der Bewertung helfen:

### Kubernetes Service Catalog / Open Service Broker (OSB)
 Dies war früher der Kubernetes-Weg, externe Services bereitzustellen. Über einen ServiceBroker und die OSB-API konnten Entwickler ServiceInstances anlegen, die dann z.B. eine DB in der Cloud provisionierten. In OpenShift existiert(e) so ein Service Catalog. Allerdings ist dieses Modell inzwischen etwas veraltet und die Kubernetes-Community hat das Projekt eingestellt. Zudem waren die vom Broker bereitgestellten CRDs relativ generisch und nicht gut in moderne GitOps-Workflows integriert. Unser Crossplane-Ansatz erreicht ähnliches (Self-Service DB etc.), aber auf Kubernetes-native Weise und mit mehr Flexibilität bei den Schnittstellen (wir können unsere eigenen CRDs definieren statt nur vorgegebene Plans des Brokers). OSB eignet sich weniger, wenn man sehr individuelle interne Services hat – es war eher für Standard-Cloud-Services gedacht.

### Direkte Terraform/Pulumi-Portal-Lösungen
 Einige Unternehmen bauen interne Portale, die bei Klick im Hintergrund Terraform-Skripte ausführen, um Infrastruktur aufzusetzen. So etwas könnte man mit z.B. ServiceNow oder einer WebUI + Terraform Cloud umsetzen. Das erfüllt den Zweck eines Marktplatzes auch (Katalog, Bestellung, Automation). Nachteile: Man hat zwei Welten – Kubernetes für Apps, Terraform für Infra – und keine gemeinsame Kontrolle. Entwickler müssten eventuell trotzdem die Besonderheiten der Terraform-Module kennen, was wieder die Hürde erhöht. Zudem fehlt die kontinuierliche Reconciliation: Terraform führt einmal aus, während Crossplane als Operator ständig drift behebt und in Kubernetes integriert ist. Unser Kubernetes-zentrischer Ansatz sorgt für eine einheitliche Plattform-API und Echtzeit-Self-Service, was mit stand-alone Terraform schwieriger zu erreichen ist (aber es ist durchaus eine Alternative, falls man Kubernetes meiden wollte).

### KubeVela (OAM)
 KubeVela ist ein Framework basierend auf dem Open Application Model, das ebenfalls abstrakte API-Schichten über Kubernetes legt. Es richtet sich primär auf Anwendungen/Workloads, kann aber auch Infrastruktur einbinden (z.B. via Crossplane). KubeVela erlaubt Platform-Teams, sogenannte Components und Traits vordefiniert anzubieten, aus denen Entwickler ihre Deployments bauen. Mit Vela könnte man z.B. einen Component-Typ „PostgresDB“ definieren, der intern Crossplane nutzt. Es bietet auch eine UI (VelaUX). Der Unterschied: KubeVela ist eher fokussiert auf Applikationsrollouts und Developer Experience, während Crossplane auf Infrastruktur fokussiert ist. In unserem Fall, wo es um expliziten Marktplatz mit Multi-Service-Abhängigkeiten geht, ist Crossplane direkter passend. Allerdings kann KubeVela als ergänzende Ebene dienen, um App-Deployment (CI/CD) mit Infrastruktur provisioning zu vereinen. Für den Prototyp ist es wahrscheinlich Overkill, aber es ist gut zu wissen, dass OAM/KubeVela existiert als Alternative, falls Crossplane allein nicht alle Wünsche erfüllt.

### KRO – Kubernetes Resource Orchestrator (von AWS)
 Ganz neu (Ende 2024) hat AWS ein Open-Source-Projekt namens KRO vorgestellt ￼. Es verfolgt ein ähnliches Ziel wie Crossplane – nämlich eigene Plattform-APIs zu definieren, die multiple Ressourcen orchestrieren – aber mit einem anderen Ansatz. Anstatt zwei Ebenen (XRD + Composition) zu schreiben, deklariert man bei KRO alles in einem Konstrukt namens ResourceGroup, das alle Komponenten beschreibt ￼ ￼. KRO generiert daraus automatisch die benötigten CRDs und Controller zur Laufzeit. Im Prinzip spart es etwas Komplexität bei der Definition. Allerdings ist KRO derzeit experimentell (Beta) und noch nicht produktionsreif ￼. Crossplane ist deutlich ausgereifter. Langfristig könnte KRO interessant werden, da es Abhängigkeiten und Reihenfolgen automatisch managen will ￼. Für unsere Entscheidung heißt das: Wir beobachten KRO, bleiben aber vorerst bei Crossplane, weil Stabilität und Community-Support wichtiger sind als Cutting-Edge-Experimente.

### Kratix (Syntasso)
 Kratix ist ein weiteres Open-Source-Framework, das genau die Idee „Marktplatz für XaaS“ adressiert. Es führt den Begriff Promise ein – ein Versprechen eines Service, das von Platform Engineers erstellt wird. Wenn ein Entwickler ein Promise anfordert, sorgt Kratix dafür, dass der nötige Service bereitgestellt wird. Intern kann Kratix z.B. Crossplane nutzen, um die Umsetzung zu erledigen. Der Vorteil von Kratix: Es bietet out-of-the-box eine Marketplace-Mechanik und unterstützt Multi-Cluster, d.h. man kann eine zentrale Kontrolle haben, die Services dann in Ziel-Clustern provisioniert. Syntasso (die Firma dahinter) vermarktet eine Enterprise-Version, aber die OSS-Version erfüllt viele Kernfunktionen. Kratix versteht sich als „intelligenter Kleber“ zwischen Frontend und IaC-Backends ￼. Es erlaubt Plattform-Teams, alles als Service anzubieten, konsumierbar über UI, API oder CLI, während z.B. Crossplane im Hintergrund die Infrastruktur baut ￼. Im Grunde ähnelt das unserem Ansatz, aber Kratix liefert schon gewisse Strukturen und ein Community-Marketplace (für gängige Promises) mit. Als Alternative könnte man also in Betracht ziehen: statt selbst alles mit Crossplane + Backstage zu kombinieren, ein Framework wie Kratix zu nutzen, das diese Kombination vereinfacht. Allerdings würde man sich dann in dessen Konzept einarbeiten müssen, und die Flexibilität ist an das Framework gebunden. In unserer Konstellation haben wir bereits Backstage vorgesehen (was gut mit Kratix integrierbar wäre) und schreiben unsere Crossplane Compositions selbst – was maximal flexibel ist. Kratix lohnt sich vielleicht zu evaluieren, falls wir feststellen, dass viel wiederkehrende Muster auftreten, die es schon als Kratix-Promise gibt.

### Eigenentwicklung / Operators
 Schließlich gibt es immer die Option, maßgeschneiderte Operatoren für jeden Service zu schreiben (z.B. einen „AIPlatform-Operator“ in Go, einen „Postgres-Operator“ etc.). Das wäre der traditionelle Weg vor Crossplane: Jedes Team implementiert einen Kubernetes-Operator, der seinen Service managt. Dies bietet volle Kontrolle, ist aber aufwändig, da viel Code geschrieben und gewartet werden muss (Controller-Logik, CRD-Schemas etc.). Crossplane reduziert diesen Aufwand drastisch, indem es als Meta-Operator fungiert – neue APIs und deren Implementierung werden durch Konfiguration statt Code erzeugt ￼. Damit erspart man sich eine Flut eigenentwickelter Controller. Angesichts der Ressourcen im Team und der gewünschten Geschwindigkeit scheidet ein komplett eigener Operator-Ansatz aus – stattdessen nutzen wir Crossplane als Framework, was sich bereits als effizient erwiesen hat.

### Fazit zu Alternativen
 Für unseren Anwendungsfall (interner Cloud-Marktplatz, starke Kubernetes-Ausrichtung) ist Crossplane mit GitOps und Backstage eine sehr passende Lösung, da sie Cloud-native Prinzipien (Deklarativität, Self-Service, API-Standardisierung) vereint. Die genannten Alternativen zeigen, dass das Konzept im Trend liegt – andere Projekte wie KubeVela, Kratix, KRO zielen in eine ähnliche Richtung, mit teils anderen Schwerpunkten. Dies bestätigt unsere Grundidee. Gleichzeitig sollten wir die Entwicklung am Markt beobachten: z.B. könnte eine Kombination aus Crossplane und KRO künftig Best Practices sein, oder Kratix könnte manche Funktionen (Multi-Cluster, Paketierung) bequemer lösen. Für den Moment bauen wir jedoch auf bewährte Komponenten auf, die gut zusammenspielen.

## 🎯 Fazit

Das skizzierte Konzept zeichnet einen Weg zu einem Kubernetes-basierten Service-Marktplatz, der Entwicklern eine moderne Self-Service-Plattform bietet. Durch den Einsatz von Crossplane als Erweiterung der Kubernetes-API können wir komplexe Infrastruktur hinter einfachen Custom Resources verbergen, sodass jede Fachdomäne (Datenbanken, Messaging, Plattform etc.) ihren Service selbst als API-Produkt anbieten kann ￼. Mit GitOps wird Konsistenz und Nachvollziehbarkeit garantiert, während Backstage als einheitliches Portal die Benutzererfahrung abrundet.

Wichtig ist, neben der Technik auch Prozesse und Kultur anzupassen – etwa klare Verantwortlichkeiten (Service Owner), Schulung der Nutzer und Richtlinien für sichere Nutzung. Starten werden wir mit einem Prototypen (z.B. auf einem Managed-K8s-Cluster in einer Sandbox-Umgebung) und Dummy-Services wie MongoDB, PostgreSQL, Kafka, DNS, Firewall, um diese Ideen in kleiner Skalierung zu validieren. In diesem Schritt können wir die Integration (CI-Pipelines, GitHub Actions, Container-Deployments nach Spot/Rackspace etc.) aufbauen und evaluieren, bevor es an kritische produktive Services geht.

Alles in allem verspricht dieser cloud-native Marktplatzansatz erhebliche Vorteile: schnellere Bereitstellung für Entwickler, weniger manuelle Tickets, konsistente Infrastruktur nach Best Practices und eine hohe Wiederverwendbarkeit von Komponenten. Die möglichen Risiken – von Komplexität bis Governance – sind beherrschbar, wenn wir sie von Anfang an berücksichtigen und mit Bedacht vorgehen. Das Konzept ist modular erweiterbar und offen für neue Tools, sodass wir auch in Zukunft modern und flexibel bleiben können. Damit schaffen wir die Grundlage für eine interne Cloud-Plattform, die unseren Entwicklern Innovation in Eigenregie ermöglicht, ohne dass dabei Chaos oder Unsicherheit entstehen. Der Weg ist anspruchsvoll, aber die Ergebnisse werden die Developer Experience und Effizienz maßgeblich verbessern.