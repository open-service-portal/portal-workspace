import { format, differenceInDays, addDays, isBefore } from 'date-fns';
import chalk from 'chalk';

/**
 * Generates Mermaid Gantt charts from processed project data
 */
export class MermaidGenerator {
  constructor() {
    // Color scheme for different priorities and states
    this.COLORS = {
      priority: {
        Critical: '#FF6B6B',    // Red
        High: '#FF9F43',        // Orange  
        Medium: '#54A0FF',      // Blue
        Low: '#5F27CD',         // Purple
      },
      status: {
        'To Do': '#95A5A6',     // Gray
        'In Progress': '#3498DB', // Blue
        'In Review': '#F39C12',  // Orange
        'Done': '#27AE60',       // Green
        'Blocked': '#E74C3C',    // Red
      },
      epic: [
        '#FF6B6B',  // Red
        '#4ECDC4',  // Teal
        '#45B7D1',  // Blue
        '#96CEB4',  // Green
        '#FFEAA7',  // Yellow
        '#DDA0DD',  // Plum
        '#98D8C8',  // Mint
        '#F7DC6F',  // Light Yellow
        '#BB8FCE',  // Light Purple
        '#85C1E9',  // Light Blue
      ]
    };

    this.MERMAID_TAGS = {
      'Critical': 'crit',
      'Done': 'done',
      'In Progress': 'active',
      'milestone': 'milestone'
    };
  }

  /**
   * Generate Mermaid Gantt chart from processed items
   * @param {Object[]} items - Processed project items
   * @param {Object} config - Generation configuration
   * @returns {string} Mermaid Gantt chart syntax
   */
  generateGantt(items, config = {}) {
    console.log(chalk.blue(`🎨 Generating Mermaid Gantt chart from ${items.length} items...`));

    const {
      title = 'Project Roadmap',
      dateFormat = 'YYYY-MM-DD',
      axisFormat = '%b %d',
      includeProgress = true,
      groupByEpic = true,
      showMilestones = true,
      maxItems = 50
    } = config;

    // Filter and sort items
    const filteredItems = this.filterAndSortItems(items, maxItems);
    
    // Group items by epic if requested
    const sections = groupByEpic ? this.groupItemsByEpic(filteredItems) : { 'Tasks': filteredItems };
    
    // Generate chart
    let mermaid = this.generateChartHeader(title, dateFormat, axisFormat);
    mermaid += this.generateThemeConfig();
    
    let isFirstSection = true;
    for (const [sectionName, sectionItems] of Object.entries(sections)) {
      if (sectionItems.length === 0) continue;
      
      // Add newline between sections (but not before the first one)
      if (!isFirstSection) {
        mermaid += '\n';
      }
      
      mermaid += this.generateSection(sectionName, sectionItems, {
        showMilestones,
        includeProgress
      });
      
      isFirstSection = false;
    }

    // Add milestones at the end
    if (showMilestones) {
      mermaid += '\n' + this.generateMilestones(filteredItems);
    }

    console.log(chalk.green(`✅ Generated Gantt chart with ${Object.keys(sections).length} sections`));
    return mermaid;
  }

  /**
   * Filter items and sort them logically
   * @param {Object[]} items - All items
   * @param {number} maxItems - Maximum items to include
   * @returns {Object[]} Filtered and sorted items
   */
  filterAndSortItems(items, maxItems) {
    // Filter to only show Epics (items that start with "Epic:" or have epic type)
    const epicItems = items.filter(item => 
      item.title && 
      item.startDate && 
      item.dueDate &&
      item.title.length > 0 &&
      (item.title.toLowerCase().startsWith('epic:') || 
       item.title.toLowerCase().startsWith('epic ') ||
       item.type === 'epic' ||
       item.labels?.some(l => l.toLowerCase() === 'epic'))
    );
    
    // If no epics found, fall back to all valid items
    const validItems = epicItems.length > 0 ? epicItems : items.filter(item => 
      item.title && 
      item.startDate && 
      item.dueDate &&
      item.title.length > 0
    );

    // Sort by priority, then by start date
    const priorityOrder = { 'Critical': 0, 'High': 1, 'Medium': 2, 'Low': 3 };
    
    const sortedItems = validItems.sort((a, b) => {
      const priorityA = priorityOrder[a.priority] ?? 4;
      const priorityB = priorityOrder[b.priority] ?? 4;
      
      if (priorityA !== priorityB) {
        return priorityA - priorityB;
      }
      
      return new Date(a.startDate) - new Date(b.startDate);
    });

    // Limit items if specified
    const limitedItems = maxItems ? sortedItems.slice(0, maxItems) : sortedItems;
    
    console.log(chalk.gray(`📊 Filtered to ${limitedItems.length} valid items (from ${items.length} total)`));
    return limitedItems;
  }

  /**
   * Group items by epic
   * @param {Object[]} items - Items to group
   * @returns {Object} Items grouped by epic
   */
  groupItemsByEpic(items) {
    const groups = {};
    
    for (const item of items) {
      const epic = item.epic || 'Other';
      if (!groups[epic]) {
        groups[epic] = [];
      }
      groups[epic].push(item);
    }

    // Sort sections by priority of their highest priority item
    const priorityOrder = { 'Critical': 0, 'High': 1, 'Medium': 2, 'Low': 3 };
    const sortedGroups = {};
    
    const sortedEpics = Object.keys(groups).sort((a, b) => {
      const maxPriorityA = Math.min(...groups[a].map(item => priorityOrder[item.priority] ?? 4));
      const maxPriorityB = Math.min(...groups[b].map(item => priorityOrder[item.priority] ?? 4));
      return maxPriorityA - maxPriorityB;
    });

    for (const epic of sortedEpics) {
      sortedGroups[epic] = groups[epic];
    }

    return sortedGroups;
  }

  /**
   * Generate chart header with configuration
   * @param {string} title - Chart title
   * @param {string} dateFormat - Date format for parsing
   * @param {string} axisFormat - Display format for axis
   * @returns {string} Mermaid header
   */
  generateChartHeader(title, dateFormat, axisFormat) {
    return `gantt\n    title ${title}\n    dateFormat ${dateFormat}\n    axisFormat ${axisFormat}\n    todayMarker stroke-width:5px,stroke:#0f0,opacity:0.75\n\n`;
  }

  /**
   * Generate theme configuration for colors
   * @returns {string} Theme configuration
   */
  generateThemeConfig() {
    // Mermaid theme configuration is handled via CSS or init directive
    // For now, we'll rely on the default theme and task tags
    return '';
  }

  /**
   * Generate a section in the Gantt chart
   * @param {string} sectionName - Name of the section
   * @param {Object[]} items - Items in this section
   * @param {Object} options - Generation options
   * @returns {string} Mermaid section syntax
   */
  generateSection(sectionName, items, options = {}) {
    const { showMilestones = true, includeProgress = true } = options;
    
    // Section line without indentation
    let section = `section ${this.sanitizeName(sectionName)}\n`;
    
    for (const item of items) {
      section += this.generateTask(item, includeProgress);
    }
    
    // No extra newline here - will be added between sections
    return section;
  }

  /**
   * Generate a single task line
   * @param {Object} item - Project item
   * @param {boolean} includeProgress - Whether to include progress indicators
   * @returns {string} Mermaid task syntax
   */
  generateTask(item, includeProgress = true) {
    const taskName = this.sanitizeTitle(item.title);
    const taskId = this.generateTaskId(item);
    const tags = this.generateTaskTags(item);
    const duration = this.calculateDuration(item);
    
    // Format: "Task Name :tag1 tag2, task_id, start_date, duration"
    // Tasks should not be indented in Gantt charts
    let task = `${taskName}`;
    
    // Add tags if present
    if (tags.length > 0) {
      task += ` :${tags.join(' ')}`;
    }
    
    // IMPORTANT: Task name MUST have a colon before the task ID!
    // If no tags, we still need the colon
    if (tags.length === 0) {
      task += ' :';
    }
    
    task += `${taskId}, ${format(item.startDate, 'yyyy-MM-dd')}, ${duration}d`;
    
    // Add progress indicator as comment if available
    if (includeProgress && item.status === 'Done') {
      task += ' %% Completed';
    } else if (includeProgress && item.status === 'In Progress') {
      task += ' %% In Progress';
    }
    
    // Ensure newline at end of task
    return task + '\n';
  }

  /**
   * Generate task tags based on priority and status
   * @param {Object} item - Project item
   * @returns {string[]} Array of tags
   */
  generateTaskTags(item) {
    const tags = [];
    
    // Add priority-based tags
    if (item.priority === 'Critical') {
      tags.push('crit');
    }
    
    // Add status-based tags
    if (item.status === 'Done') {
      tags.push('done');
    } else if (item.status === 'In Progress') {
      tags.push('active');
    }
    
    return tags;
  }

  /**
   * Calculate task duration in days
   * @param {Object} item - Project item  
   * @returns {number} Duration in days
   */
  calculateDuration(item) {
    if (!item.startDate || !item.dueDate) {
      return 1; // Default 1 day
    }
    
    const days = differenceInDays(item.dueDate, item.startDate);
    return Math.max(1, days); // Minimum 1 day
  }

  /**
   * Generate unique task ID
   * @param {Object} item - Project item
   * @returns {string} Task ID
   */
  generateTaskId(item) {
    // Use item number if available, otherwise create from title
    if (item.number) {
      return `task${item.number}`;
    }
    
    // Generate from title
    const slug = item.title
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_|_$/g, '')
      .substring(0, 20);
    
    return `task_${slug}`;
  }

  /**
   * Sanitize section/epic names for Mermaid
   * @param {string} name - Raw name
   * @returns {string} Sanitized name
   */
  sanitizeName(name) {
    return name.replace(/[^\w\s-]/g, '').trim() || 'Unnamed';
  }

  /**
   * Sanitize and shorten task titles for display
   * @param {string} title - Raw title
   * @returns {string} Sanitized title
   */
  sanitizeTitle(title) {
    // Remove special characters that break Mermaid syntax
    let cleaned = title
      .replace(/[:;\[\](){},]/g, '')  // Remove colons, semicolons, commas, brackets
      .replace(/\s+/g, ' ')
      .trim();
    
    // Truncate if too long
    if (cleaned.length > 40) {
      cleaned = cleaned.substring(0, 37) + '...';
    }
    
    return cleaned || 'Untitled Task';
  }

  /**
   * Generate milestone markers
   * @param {Object[]} items - All items
   * @returns {string} Milestone syntax
   */
  generateMilestones(items) {
    const milestones = [];
    
    // Extract milestones from items
    for (const item of items) {
      // Add GitHub milestone as Mermaid milestone
      if (item.milestone && item.milestone.dueDate) {
        milestones.push({
          title: item.milestone.title,
          date: item.milestone.dueDate,
          type: 'milestone'
        });
      }
      
      // Add project milestone
      if (item.projectMilestone && item.projectMilestone.dueDate) {
        milestones.push({
          title: item.projectMilestone.title,
          date: item.projectMilestone.dueDate,
          type: 'milestone'
        });
      }

      // Mark completed high-priority items as milestones
      if (item.status === 'Done' && item.priority === 'Critical' && item.dueDate) {
        milestones.push({
          title: `${item.title} Complete`,
          date: item.closedAt || item.dueDate,
          type: 'milestone'
        });
      }
    }

    // Remove duplicates and sort by date
    const uniqueMilestones = milestones.filter((milestone, index, arr) => 
      arr.findIndex(m => m.title === milestone.title && 
                         format(m.date, 'yyyy-MM-dd') === format(milestone.date, 'yyyy-MM-dd')) === index
    ).sort((a, b) => new Date(a.date) - new Date(b.date));

    if (uniqueMilestones.length === 0) {
      return '';
    }

    let milestoneSection = 'section Milestones\n';
    
    for (const milestone of uniqueMilestones.slice(0, 5)) { // Limit to 5 milestones
      const milestoneTitle = this.sanitizeTitle(milestone.title);
      const milestoneId = this.generateTaskId({ title: milestone.title });
      
      milestoneSection += `${milestoneTitle} :milestone, ${milestoneId}, ${format(milestone.date, 'yyyy-MM-dd')}, 0d\n`;
    }

    return milestoneSection;
  }

  /**
   * Generate a summary statistics section
   * @param {Object[]} items - All processed items
   * @returns {string} Statistics markdown
   */
  generateStatistics(items) {
    const stats = {
      total: items.length,
      done: items.filter(item => item.status === 'Done').length,
      inProgress: items.filter(item => item.status === 'In Progress').length,
      todo: items.filter(item => item.status === 'To Do').length,
      critical: items.filter(item => item.priority === 'Critical').length,
      high: items.filter(item => item.priority === 'High').length,
    };

    const progress = stats.total > 0 ? Math.round((stats.done / stats.total) * 100) : 0;

    return `\n## 📊 Project Statistics

- **Total Epics:** ${stats.total}
- **Completed:** ${stats.done} (${progress}%)  
- **In Progress:** ${stats.inProgress}
- **To Do:** ${stats.todo}
- **Critical Priority:** ${stats.critical}
- **High Priority:** ${stats.high}

### 🔗 Quick Links
- [📋 Project Board](https://github.com/orgs/open-service-portal/projects/1)
- [🗺️ Interactive Roadmap View](https://github.com/orgs/open-service-portal/projects/1/views/3)
- [📊 Table View](https://github.com/orgs/open-service-portal/projects/1/views/1)
- [🎯 Kanban Board](https://github.com/orgs/open-service-portal/projects/1/views/2)

*Last updated: ${format(new Date(), 'MMM dd, yyyy')} at ${format(new Date(), 'HH:mm')} UTC*`;
  }
}