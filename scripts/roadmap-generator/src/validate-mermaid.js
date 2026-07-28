#!/usr/bin/env node
import { writeFileSync, unlinkSync, existsSync } from 'fs';
import { execSync } from 'child_process';
import chalk from 'chalk';
import path from 'path';

/**
 * Validate Mermaid syntax using mermaid-cli
 */
export class MermaidValidator {
  constructor() {
    this.mmdc = this.findMmdc();
  }

  /**
   * Find mmdc executable
   * @returns {string} Path to mmdc
   */
  findMmdc() {
    const possiblePaths = [
      './node_modules/.bin/mmdc',
      '../node_modules/.bin/mmdc',
      '../../node_modules/.bin/mmdc',
      'mmdc'
    ];

    for (const mmdc of possiblePaths) {
      try {
        execSync(`${mmdc} --version`, { stdio: 'ignore' });
        console.log(chalk.gray(`Found mmdc at: ${mmdc}`));
        return mmdc;
      } catch (e) {
        // Continue searching
      }
    }

    console.warn(chalk.yellow('⚠️ mmdc not found - skipping validation'));
    return null;
  }

  /**
   * Validate Mermaid chart syntax
   * @param {string} mermaidChart - The Mermaid chart to validate
   * @returns {Object} Validation result { valid: boolean, error?: string }
   */
  async validate(mermaidChart) {
    if (!this.mmdc) {
      return { valid: true, warning: 'Validation skipped - mmdc not installed' };
    }

    const tempFile = `/tmp/mermaid-test-${Date.now()}.mmd`;
    const outputFile = `/tmp/mermaid-test-${Date.now()}.svg`;

    try {
      // Write chart to temp file
      writeFileSync(tempFile, mermaidChart, 'utf8');

      // Try to render with mmdc
      const result = execSync(
        `${this.mmdc} -i ${tempFile} -o ${outputFile} --quiet`,
        { 
          encoding: 'utf8',
          stdio: ['pipe', 'pipe', 'pipe']
        }
      );

      // Clean up
      if (existsSync(tempFile)) unlinkSync(tempFile);
      if (existsSync(outputFile)) unlinkSync(outputFile);

      console.log(chalk.green('✅ Mermaid syntax is valid'));
      return { valid: true };

    } catch (error) {
      // Clean up temp files
      if (existsSync(tempFile)) unlinkSync(tempFile);
      if (existsSync(outputFile)) unlinkSync(outputFile);

      const errorMessage = error.stderr || error.message || 'Unknown error';
      console.error(chalk.red('❌ Mermaid syntax error:'));
      console.error(chalk.red(errorMessage));

      // Try to extract the specific error
      const lines = mermaidChart.split('\n');
      const errorMatch = errorMessage.match(/line (\d+)/i);
      if (errorMatch) {
        const lineNum = parseInt(errorMatch[1]);
        if (lineNum > 0 && lineNum <= lines.length) {
          console.error(chalk.red(`Line ${lineNum}: ${lines[lineNum - 1]}`));
        }
      }

      return { 
        valid: false, 
        error: errorMessage 
      };
    }
  }

  /**
   * Check common Gantt chart issues
   * @param {string} mermaidChart - The chart to check
   * @returns {string[]} Array of warnings
   */
  checkCommonIssues(mermaidChart) {
    const warnings = [];
    const lines = mermaidChart.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      
      // Check for commas in task names (before the task ID)
      if (line.includes(',') && !line.startsWith('%%')) {
        const parts = line.split(',');
        if (parts.length > 3) {
          warnings.push(`Line ${i + 1}: Task name may contain comma which breaks syntax`);
        }
      }

      // Check for missing task IDs
      if (line.length > 0 && 
          !line.startsWith('gantt') && 
          !line.startsWith('title') && 
          !line.startsWith('dateFormat') &&
          !line.startsWith('axisFormat') &&
          !line.startsWith('section') &&
          !line.startsWith('%%') &&
          !line.includes('todayMarker') &&
          line.includes(',')) {
        const parts = line.split(',');
        if (parts.length < 3) {
          warnings.push(`Line ${i + 1}: Task may be missing required fields (name, id, date, duration)`);
        }
      }

      // Check for invalid characters
      if (line.includes(':') && !line.includes('milestone') && !line.includes('crit') && !line.includes('done') && !line.includes('active')) {
        if (!line.startsWith('%%')) {
          warnings.push(`Line ${i + 1}: Contains ':' which may break syntax unless it's a tag`);
        }
      }
    }

    return warnings;
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const validator = new MermaidValidator();
  
  // Test with a sample chart
  const testChart = `gantt
    title Test Chart
    dateFormat YYYY-MM-DD
    
    section Test
    Task 1 :task1, 2025-01-01, 30d
    Task 2 :task2, after task1, 20d`;

  validator.validate(testChart).then(result => {
    if (result.valid) {
      console.log(chalk.green('✅ Validation test passed'));
    } else {
      console.error(chalk.red('❌ Validation test failed'));
      process.exit(1);
    }
  });
}