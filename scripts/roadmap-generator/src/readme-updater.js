import { readFile, writeFile } from 'fs/promises';
import { existsSync } from 'fs';
import chalk from 'chalk';

/**
 * Updates README.md with generated Mermaid Gantt chart
 */
export class ReadmeUpdater {
  constructor() {
    this.ROADMAP_MARKERS = {
      start: '<!-- ROADMAP-START -->',
      end: '<!-- ROADMAP-END -->'
    };
  }

  /**
   * Update README.md with the generated roadmap
   * @param {string} mermaidChart - Generated Mermaid Gantt chart
   * @param {string} statistics - Statistics section
   * @param {string} readmePath - Path to README.md file
   * @returns {Promise<boolean>} True if file was updated
   */
  async updateReadme(mermaidChart, statistics = '', readmePath = 'README.md') {
    console.log(chalk.blue(`📝 Updating ${readmePath}...`));

    try {
      // Read existing README or create template if it doesn't exist
      let content = '';
      if (existsSync(readmePath)) {
        content = await readFile(readmePath, 'utf8');
      } else {
        console.log(chalk.yellow(`⚠️  README.md not found, creating new file...`));
        content = this.generateDefaultReadmeTemplate();
      }

      // Generate roadmap section content
      const roadmapSection = this.generateRoadmapSection(mermaidChart, statistics);

      // Update content
      const updatedContent = this.insertOrUpdateRoadmapSection(content, roadmapSection);

      // Write back to file
      await writeFile(readmePath, updatedContent, 'utf8');
      console.log(chalk.green(`✅ Successfully updated ${readmePath}`));
      
      return true;
    } catch (error) {
      console.error(chalk.red(`❌ Error updating README: ${error.message}`));
      throw error;
    }
  }

  /**
   * Generate default README template if file doesn't exist
   * @returns {string} Default README content
   */
  generateDefaultReadmeTemplate() {
    return `# Open Service Portal

A modern service portal built with Backstage for managing and discovering services.

## 🗓️ Project Roadmap

${this.ROADMAP_MARKERS.start}
<!-- Roadmap will be automatically generated here -->
${this.ROADMAP_MARKERS.end}

## Features

- Service discovery and cataloging
- Template-based service creation
- Integrated documentation
- Developer portal interface

## Getting Started

\`\`\`bash
# Clone the repository
git clone <repository-url>

# Install dependencies  
cd app-portal
yarn install

# Start the development server
yarn start
\`\`\`

## Contributing

We welcome contributions! Please see our contributing guidelines for more information.

## License

This project is licensed under the MIT License.
`;
  }

  /**
   * Generate the complete roadmap section
   * @param {string} mermaidChart - Mermaid chart syntax
   * @param {string} statistics - Statistics section
   * @returns {string} Complete roadmap section
   */
  generateRoadmapSection(mermaidChart, statistics) {
    const timestamp = new Date().toISOString();
    
    return `## 🗓️ Project Roadmap

This roadmap is automatically generated from our GitHub Project and updated every Friday.

\`\`\`mermaid
${mermaidChart.trim()}
\`\`\`

${statistics}

---
*🤖 This roadmap is automatically generated from [GitHub Projects](https://github.com/orgs/open-service-portal/projects/1) every Friday at 16:00 UTC*  
*View the [interactive roadmap](https://github.com/orgs/open-service-portal/projects/1/views/3) for real-time updates*  
*Generated on: ${new Date().toLocaleDateString('en-US', { 
  weekday: 'long', 
  year: 'numeric', 
  month: 'long', 
  day: 'numeric',
  timeZone: 'UTC'
})}*`;
  }

  /**
   * Insert or update the roadmap section in existing content
   * @param {string} content - Existing README content
   * @param {string} roadmapSection - New roadmap section
   * @returns {string} Updated content
   */
  insertOrUpdateRoadmapSection(content, roadmapSection) {
    const startIndex = content.indexOf(this.ROADMAP_MARKERS.start);
    const endIndex = content.indexOf(this.ROADMAP_MARKERS.end);

    if (startIndex !== -1 && endIndex !== -1) {
      // Replace existing roadmap section
      const before = content.substring(0, startIndex);
      const after = content.substring(endIndex + this.ROADMAP_MARKERS.end.length);
      
      return `${before}${this.ROADMAP_MARKERS.start}\n${roadmapSection}\n${this.ROADMAP_MARKERS.end}${after}`;
    } else if (startIndex !== -1 && endIndex === -1) {
      // Start marker exists but no end marker - add end marker
      console.log(chalk.yellow('⚠️  Found start marker but no end marker, adding end marker'));
      const before = content.substring(0, startIndex);
      const after = content.substring(startIndex + this.ROADMAP_MARKERS.start.length);
      
      return `${before}${this.ROADMAP_MARKERS.start}\n${roadmapSection}\n${this.ROADMAP_MARKERS.end}${after}`;
    } else {
      // No roadmap section exists - add it after the first heading
      const lines = content.split('\n');
      let insertIndex = 0;
      
      // Find the first h1 heading and insert after it
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('# ')) {
          insertIndex = i + 1;
          // Skip any existing content until we find a good spot
          while (insertIndex < lines.length && 
                 (lines[insertIndex].trim() === '' || 
                  lines[insertIndex].startsWith('[![') ||
                  lines[insertIndex].startsWith('![') ||
                  lines[insertIndex].trim().startsWith('<'))) {
            insertIndex++;
          }
          break;
        }
      }

      // Insert roadmap section
      const before = lines.slice(0, insertIndex).join('\n');
      const after = lines.slice(insertIndex).join('\n');
      
      const roadmapWithMarkers = `\n${this.ROADMAP_MARKERS.start}\n${roadmapSection}\n${this.ROADMAP_MARKERS.end}\n`;
      
      return before + roadmapWithMarkers + after;
    }
  }

  /**
   * Validate that the README was updated correctly
   * @param {string} readmePath - Path to README file
   * @returns {Promise<boolean>} True if validation passes
   */
  async validateUpdate(readmePath = 'README.md') {
    try {
      const content = await readFile(readmePath, 'utf8');
      
      const hasStartMarker = content.includes(this.ROADMAP_MARKERS.start);
      const hasEndMarker = content.includes(this.ROADMAP_MARKERS.end);
      const hasMermaidChart = content.includes('```mermaid') && content.includes('gantt');
      
      if (!hasStartMarker || !hasEndMarker) {
        console.error(chalk.red('❌ README markers not found'));
        return false;
      }
      
      if (!hasMermaidChart) {
        console.error(chalk.red('❌ Mermaid Gantt chart not found in README'));
        return false;
      }

      console.log(chalk.green('✅ README validation passed'));
      return true;
    } catch (error) {
      console.error(chalk.red(`❌ README validation failed: ${error.message}`));
      return false;
    }
  }

  /**
   * Create a backup of the README before updating
   * @param {string} readmePath - Path to README file
   * @returns {Promise<string>} Path to backup file
   */
  async createBackup(readmePath = 'README.md') {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupPath = `${readmePath}.backup.${timestamp}`;
    
    try {
      if (existsSync(readmePath)) {
        const content = await readFile(readmePath, 'utf8');
        await writeFile(backupPath, content, 'utf8');
        console.log(chalk.gray(`📋 Created backup: ${backupPath}`));
      }
      return backupPath;
    } catch (error) {
      console.error(chalk.yellow(`⚠️  Could not create backup: ${error.message}`));
      return '';
    }
  }

  /**
   * Generate a preview of the changes without writing to file
   * @param {string} mermaidChart - Generated chart
   * @param {string} statistics - Statistics section  
   * @param {string} readmePath - Path to README file
   * @returns {Promise<string>} Preview of updated content
   */
  async generatePreview(mermaidChart, statistics = '', readmePath = 'README.md') {
    let content = '';
    
    if (existsSync(readmePath)) {
      content = await readFile(readmePath, 'utf8');
    } else {
      content = this.generateDefaultReadmeTemplate();
    }

    const roadmapSection = this.generateRoadmapSection(mermaidChart, statistics);
    return this.insertOrUpdateRoadmapSection(content, roadmapSection);
  }
}