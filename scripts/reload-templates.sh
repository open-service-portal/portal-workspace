#!/bin/bash

# Delete and reload all Crossplane templates
echo "🔄 Reloading Crossplane templates..."

# Delete XRDs and Compositions
kubectl delete xrd --all 2>/dev/null
kubectl delete composition --all 2>/dev/null

# Force Flux to reconcile all template sources
for template in $(flux get sources git -n flux-system | grep template- | awk '{print $1}'); do
  echo "♻️  Reconciling $template..."
  flux reconcile source git $template -n flux-system
  flux reconcile kustomization $template -n flux-system
done

echo "✅ Templates reloaded!"