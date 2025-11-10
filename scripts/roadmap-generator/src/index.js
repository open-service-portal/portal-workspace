#!/usr/bin/env node

import 'dotenv/config';
import { GitHubClient } from './github-client.js';
import { DataProcessor } from './data-processor.js';
import { MermaidGenerator } from './mermaid-generator.js';
import { ReadmeUpdater } from './readme-updater.js';
import { MermaidValidator } from './validate-mermaid.js';
import chalk from 'chalk';
import { format } from 'date-fns';

/**
 * Main application class for roadmap generation
 */
class RoadmapGenerator {
  constructor() {
    this.config = this.loadConfiguration();
    this.githubClient = new GitHubClient(this.config.token);
    this.dataProcessor = new DataProcessor();
    this.mermaidGenerator = new MermaidGenerator();
    this.readmeUpdater = new ReadmeUpdater();
    this.mermaidValidator = new MermaidValidator();
  }

  /**
   * Load configuration from environment variables
   * @returns {Object} Configuration object
   */
  loadConfiguration() {
    // Support both GITHUB_ORG and ORGANIZATION for flexibility
    const organization = process.env.GITHUB_ORG || process.env.ORGANIZATION;
    
    if (!organization) {
      console.error(chalk.red(`❌ Missing required environment variable: GITHUB_ORG or ORGANIZATION`));
      process.exit(1);
    }

    // Use GitHub CLI token as fallback for local development
    const token = process.env.GITHUB_TOKEN || '';

    return {
      token: token,
      organization: organization,
      projectNumber: parseInt(process.env.PROJECT_ID || '1', 10),
      repository: process.env.GITHUB_REPOSITORY,
      readmePath: process.env.README_PATH || 'README.md',
      maxItems: parseInt(process.env.MAX_ITEMS || '50', 10),
      dryRun: process.env.DRY_RUN === 'true',
      verbose: process.env.VERBOSE === 'true',
    };
  }

  /**
   * Main execution function
   */
  async run() {
    console.log(chalk.blue('🚀 Starting roadmap generation...'));
    console.log(chalk.gray(`📅 ${format(new Date(), 'PPpp')}`));
    
    if (this.config.verbose) {
      console.log(chalk.gray('Configuration:'));
      console.log(chalk.gray(`  Organization: ${this.config.organization}`));
      console.log(chalk.gray(`  Project: #${this.config.projectNumber}`));
      console.log(chalk.gray(`  Repository: ${this.config.repository || 'N/A'}`));
      console.log(chalk.gray(`  README Path: ${this.config.readmePath}`));
      console.log(chalk.gray(`  Max Items: ${this.config.maxItems}`));
      console.log(chalk.gray(`  Dry Run: ${this.config.dryRun}`));
    }

    try {
      // Step 1: Fetch project data
      await this.fetchProjectData();

      // Step 2: Process the raw data
      await this.processData();

      // Step 3: Generate Mermaid chart
      await this.generateChart();

      // Step 4: Update README (unless dry run)
      if (!this.config.dryRun) {
        await this.updateReadme();
        console.log(chalk.green('✅ Roadmap generation completed successfully!'));
      } else {
        console.log(chalk.yellow('✅ Dry run completed - no files were modified'));
      }

    } catch (error) {
      console.error(chalk.red('💥 Roadmap generation failed:'));
      console.error(chalk.red(error.message));
      
      if (this.config.verbose && error.stack) {
        console.error(chalk.red('Stack trace:'));
        console.error(chalk.red(error.stack));
      }
      
      process.exit(1);
    }
  }

  /**
   * Fetch project data from GitHub
   */
  async fetchProjectData() {
    console.log(chalk.blue('\n📡 Step 1: Fetching project data...'));
    
    try {
      // Get project information and fields
      this.project = await this.githubClient.getProject(
        this.config.organization, 
        this.config.projectNumber
      );

      if (this.config.verbose) {
        console.log(chalk.gray(`Project: ${this.project.title}`));
        console.log(chalk.gray(`Description: ${this.project.shortDescription || 'None'}`));
        console.log(chalk.gray(`Fields: ${this.project.fields.nodes.length}`));
      }

      // Get all project items
      this.rawItems = await this.githubClient.getProjectItems(this.project.id);

      if (this.rawItems.length === 0) {
        console.warn(chalk.yellow('⚠️  No items found in project. The roadmap will be empty.'));
        return;
      }

      console.log(chalk.green(`✅ Successfully fetched ${this.rawItems.length} items`));

    } catch (error) {
      if (error.message.includes('not found')) {
        console.error(chalk.red(`❌ Project #${this.config.projectNumber} not found in organization '${this.config.organization}'`));
        console.error(chalk.red('💡 Try listing available projects first:'));
        
        try {
          const projects = await this.githubClient.getOrganizationProjects(this.config.organization);
          if (projects.length > 0) {
            console.log(chalk.yellow('Available projects:'));
            projects.forEach(p => console.log(chalk.yellow(`  #${p.number}: ${p.title}`)));
          }
        } catch (listError) {
          console.error(chalk.red('Could not list projects. Check your token permissions.'));
        }
      }
      throw error;
    }
  }

  /**
   * Process raw GitHub data into structured format
   */
  async processData() {
    if (!this.rawItems || this.rawItems.length === 0) {
      console.log(chalk.yellow('⏭️  Skipping data processing - no items to process'));
      this.processedItems = [];
      return;
    }

    console.log(chalk.blue('\n🔄 Step 2: Processing project data...'));
    
    try {
      this.processedItems = this.dataProcessor.processItems(
        this.rawItems,
        this.project.fields.nodes
      );

      if (this.config.verbose && this.processedItems.length > 0) {
        const sample = this.processedItems[0];
        console.log(chalk.gray('Sample processed item:'));
        console.log(chalk.gray(`  Title: ${sample.title}`));
        console.log(chalk.gray(`  Epic: ${sample.epic || 'None'}`));
        console.log(chalk.gray(`  Status: ${sample.status || 'None'}`));
        console.log(chalk.gray(`  Priority: ${sample.priority || 'None'}`));
        console.log(chalk.gray(`  Start: ${sample.startDate ? format(sample.startDate, 'MMM dd, yyyy') : 'None'}`));
        console.log(chalk.gray(`  Due: ${sample.dueDate ? format(sample.dueDate, 'MMM dd, yyyy') : 'None'}`));
      }

      // Analyze data quality
      this.analyzeDataQuality();

    } catch (error) {
      console.error(chalk.red('Failed to process project data'));
      throw error;
    }
  }

  /**
   * Analyze and report on data quality
   */
  analyzeDataQuality() {
    if (!this.processedItems.length) return;

    const stats = {
      withDates: this.processedItems.filter(item => item.startDate && item.dueDate).length,
      withEpic: this.processedItems.filter(item => item.epic && item.epic !== 'Other').length,
      withPriority: this.processedItems.filter(item => item.priority).length,
      withStatus: this.processedItems.filter(item => item.status).length,
      estimatedDates: this.processedItems.filter(item => item.isEstimatedDueDate).length,
    };

    console.log(chalk.blue('\n📊 Data Quality Analysis:'));
    console.log(chalk.gray(`  Items with dates: ${stats.withDates}/${this.processedItems.length} (${Math.round(stats.withDates/this.processedItems.length*100)}%)`));
    console.log(chalk.gray(`  Items with epics: ${stats.withEpic}/${this.processedItems.length} (${Math.round(stats.withEpic/this.processedItems.length*100)}%)`));
    console.log(chalk.gray(`  Items with priority: ${stats.withPriority}/${this.processedItems.length} (${Math.round(stats.withPriority/this.processedItems.length*100)}%)`));
    console.log(chalk.gray(`  Items with status: ${stats.withStatus}/${this.processedItems.length} (${Math.round(stats.withStatus/this.processedItems.length*100)}%)`));
    
    if (stats.estimatedDates > 0) {
      console.log(chalk.yellow(`  ⚠️  ${stats.estimatedDates} items have estimated due dates`));
    }

    if (stats.withDates < this.processedItems.length * 0.5) {
      console.log(chalk.yellow('  ⚠️  Less than 50% of items have proper dates - consider adding Start Date and Due Date fields to your project'));
    }
  }

  /**
   * Generate Mermaid Gantt chart
   */
  async generateChart() {
    console.log(chalk.blue('\n🎨 Step 3: Generating Mermaid chart...'));
    
    try {
      const chartConfig = {
        title: this.project.title || 'Project Roadmap',
        dateFormat: 'YYYY-MM-DD',
        axisFormat: '%b %d',
        includeProgress: true,
        groupByEpic: true,
        showMilestones: true,
        maxItems: this.config.maxItems,
      };

      this.mermaidChart = this.mermaidGenerator.generateGantt(
        this.processedItems,
        chartConfig
      );

      this.statistics = this.mermaidGenerator.generateStatistics(this.processedItems);

      if (this.config.verbose) {
        console.log(chalk.gray('\nGenerated Mermaid chart preview:'));
        const preview = this.mermaidChart.split('\n').slice(0, 10).join('\n');
        console.log(chalk.gray(preview + (this.mermaidChart.split('\n').length > 10 ? '\n...' : '')));
      }

      // Validate the generated chart
      console.log(chalk.blue('\n🔍 Validating Mermaid syntax...'));
      const validation = await this.mermaidValidator.validate(this.mermaidChart);
      
      if (!validation.valid) {
        console.error(chalk.red('❌ Generated Mermaid chart has syntax errors'));
        
        // Check for common issues
        const warnings = this.mermaidValidator.checkCommonIssues(this.mermaidChart);
        if (warnings.length > 0) {
          console.log(chalk.yellow('\n⚠️ Common issues detected:'));
          warnings.forEach(w => console.log(chalk.yellow(`  - ${w}`)));
        }
        
        if (!this.config.dryRun) {
          throw new Error('Mermaid validation failed - chart would be invalid');
        }
      }

    } catch (error) {
      console.error(chalk.red('Failed to generate Mermaid chart'));
      throw error;
    }
  }

  /**
   * Update README file with generated chart
   */
  async updateReadme() {
    console.log(chalk.blue('\n📝 Step 4: Updating README...'));
    
    try {
      // Create backup first
      await this.readmeUpdater.createBackup(this.config.readmePath);

      // Update README
      await this.readmeUpdater.updateReadme(
        this.mermaidChart,
        this.statistics,
        this.config.readmePath
      );

      // Validate the update
      const isValid = await this.readmeUpdater.validateUpdate(this.config.readmePath);
      if (!isValid) {
        throw new Error('README validation failed after update');
      }

    } catch (error) {
      console.error(chalk.red('Failed to update README'));
      throw error;
    }
  }

  /**
   * Handle graceful shutdown
   */
  async handleShutdown() {
    console.log(chalk.yellow('\n🛑 Received shutdown signal, cleaning up...'));
    process.exit(0);
  }
}

// Handle process signals
process.on('SIGINT', async () => {
  const app = new RoadmapGenerator();
  await app.handleShutdown();
});

process.on('SIGTERM', async () => {
  const app = new RoadmapGenerator();  
  await app.handleShutdown();
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error(chalk.red('💥 Unhandled Rejection at:'), promise);
  console.error(chalk.red('Reason:'), reason);
  process.exit(1);
});

// Run the application if this is the main module
if (import.meta.url === `file://${process.argv[1]}`) {
  const generator = new RoadmapGenerator();
  generator.run().catch(error => {
    console.error(chalk.red('💥 Fatal error:'), error);
    process.exit(1);
  });
}