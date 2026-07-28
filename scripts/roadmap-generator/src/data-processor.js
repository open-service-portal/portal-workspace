import { format, addDays, addWeeks, parseISO, isValid } from 'date-fns';
import chalk from 'chalk';

/**
 * Processes raw GitHub Projects v2 data into structured format for Mermaid generation
 */
export class DataProcessor {
  constructor() {
    // Standard field names that we look for in custom fields
    this.FIELD_MAPPINGS = {
      epic: ['Epic', 'epic', 'Epic/Theme', 'Feature Area'],
      priority: ['Priority', 'priority', 'Urgency', 'Importance'],
      status: ['Status', 'status', 'State', 'Progress'],
      startDate: ['Start Date', 'start date', 'startDate', 'Started'],
      dueDate: ['Due Date', 'due date', 'dueDate', 'Target Date', 'End Date'],
      estimation: ['Story Points', 'Points', 'Estimation', 'Effort', 'Size'],
      sprint: ['Sprint', 'Iteration', 'Milestone'],
    };
  }

  /**
   * Process project items into structured data
   * @param {Object[]} rawItems - Raw items from GitHub API
   * @param {Object[]} projectFields - Project field definitions
   * @returns {Object[]} Processed items
   */
  processItems(rawItems, projectFields) {
    console.log(chalk.blue(`🔄 Processing ${rawItems.length} items...`));

    const fieldMap = this.createFieldMap(projectFields);
    const processedItems = [];

    for (const item of rawItems) {
      if (!item.content) {
        console.log(chalk.yellow(`⚠️  Skipping item without content: ${item.id}`));
        continue;
      }

      try {
        const processed = this.processItem(item, fieldMap);
        if (processed) {
          processedItems.push(processed);
        }
      } catch (error) {
        console.error(chalk.red(`❌ Error processing item ${item.id}: ${error.message}`));
      }
    }

    console.log(chalk.green(`✅ Processed ${processedItems.length} items successfully`));
    return this.enrichItemsWithDefaults(processedItems);
  }

  /**
   * Create a map of field IDs to field definitions for quick lookup
   * @param {Object[]} projectFields - Project field definitions
   * @returns {Map} Field map
   */
  createFieldMap(projectFields) {
    const fieldMap = new Map();
    
    for (const field of projectFields) {
      fieldMap.set(field.id, field);
    }

    console.log(chalk.gray(`📊 Created field map with ${fieldMap.size} fields`));
    return fieldMap;
  }

  /**
   * Process a single project item
   * @param {Object} item - Raw project item
   * @param {Map} fieldMap - Field definitions map
   * @returns {Object} Processed item
   */
  processItem(item, fieldMap) {
    const content = item.content;
    
    // Base item data
    const processed = {
      id: item.id,
      title: content.title,
      url: content.url,
      state: content.state,
      type: content.__typename === 'Issue' ? 'issue' : 
             content.__typename === 'PullRequest' ? 'pullrequest' : 'draft',
      labels: content.labels?.nodes?.map(label => label.name) || [],
      assignees: content.assignees?.nodes?.map(assignee => assignee.login) || [],
      createdAt: content.createdAt ? parseISO(content.createdAt) : null,
      closedAt: content.closedAt ? parseISO(content.closedAt) : null,
      number: content.number,
    };

    // Add milestone if present
    if (content.milestone) {
      processed.milestone = {
        title: content.milestone.title,
        dueDate: content.milestone.dueOn ? parseISO(content.milestone.dueOn) : null,
        state: content.milestone.state,
      };
    }

    // Process custom field values
    this.processFieldValues(item.fieldValues?.nodes || [], fieldMap, processed);

    return processed;
  }

  /**
   * Process custom field values for an item
   * @param {Object[]} fieldValues - Field values from API
   * @param {Map} fieldMap - Field definitions map  
   * @param {Object} processed - Processed item to update
   */
  processFieldValues(fieldValues, fieldMap, processed) {
    for (const fieldValue of fieldValues) {
      const field = fieldMap.get(fieldValue.field?.id);
      if (!field) continue;

      const fieldName = field.name;
      const mappedField = this.findMappedField(fieldName);

      switch (fieldValue.__typename) {
        case 'ProjectV2ItemFieldTextValue':
          this.processTextValue(fieldValue, mappedField, fieldName, processed);
          break;
        case 'ProjectV2ItemFieldSingleSelectValue':
          this.processSingleSelectValue(fieldValue, mappedField, fieldName, processed);
          break;
        case 'ProjectV2ItemFieldDateValue':
          this.processDateValue(fieldValue, mappedField, fieldName, processed);
          break;
        case 'ProjectV2ItemFieldNumberValue':
          this.processNumberValue(fieldValue, mappedField, fieldName, processed);
          break;
        case 'ProjectV2ItemFieldMilestoneValue':
          this.processMilestoneValue(fieldValue, processed);
          break;
        case 'ProjectV2ItemFieldIterationValue':
          this.processIterationValue(fieldValue, processed);
          break;
      }
    }
  }

  /**
   * Find which standard field a custom field name maps to
   * @param {string} fieldName - Custom field name
   * @returns {string|null} Mapped field name
   */
  findMappedField(fieldName) {
    for (const [mappedField, variations] of Object.entries(this.FIELD_MAPPINGS)) {
      if (variations.some(variation => 
        fieldName.toLowerCase().includes(variation.toLowerCase()))) {
        return mappedField;
      }
    }
    return null;
  }

  processTextValue(fieldValue, mappedField, fieldName, processed) {
    if (mappedField) {
      processed[mappedField] = fieldValue.text;
    } else {
      processed.customFields = processed.customFields || {};
      processed.customFields[fieldName] = fieldValue.text;
    }
  }

  processSingleSelectValue(fieldValue, mappedField, fieldName, processed) {
    if (mappedField) {
      processed[mappedField] = fieldValue.name;
    } else {
      processed.customFields = processed.customFields || {};
      processed.customFields[fieldName] = fieldValue.name;
    }
  }

  processDateValue(fieldValue, mappedField, fieldName, processed) {
    const date = fieldValue.date ? parseISO(fieldValue.date) : null;
    if (date && isValid(date)) {
      if (mappedField) {
        processed[mappedField] = date;
      } else {
        processed.customFields = processed.customFields || {};
        processed.customFields[fieldName] = date;
      }
    }
  }

  processNumberValue(fieldValue, mappedField, fieldName, processed) {
    if (mappedField) {
      processed[mappedField] = fieldValue.number;
    } else {
      processed.customFields = processed.customFields || {};
      processed.customFields[fieldName] = fieldValue.number;
    }
  }

  processMilestoneValue(fieldValue, processed) {
    if (fieldValue.milestone) {
      processed.projectMilestone = {
        title: fieldValue.milestone.title,
        description: fieldValue.milestone.description,
        dueDate: fieldValue.milestone.dueOn ? parseISO(fieldValue.milestone.dueOn) : null,
        state: fieldValue.milestone.state,
      };
    }
  }

  processIterationValue(fieldValue, processed) {
    processed.iteration = {
      title: fieldValue.title,
      startDate: fieldValue.startDate ? parseISO(fieldValue.startDate) : null,
      duration: fieldValue.duration,
    };
  }

  /**
   * Enrich processed items with defaults and computed values
   * @param {Object[]} items - Processed items
   * @returns {Object[]} Enriched items
   */
  enrichItemsWithDefaults(items) {
    console.log(chalk.blue('🔧 Enriching items with defaults...'));

    return items.map(item => {
      // Set default epic based on labels if not present
      if (!item.epic) {
        item.epic = this.inferEpicFromLabels(item.labels) || 'Other';
      }

      // Set default priority if not present
      if (!item.priority) {
        item.priority = this.inferPriorityFromLabels(item.labels) || 'Medium';
      }

      // Set default status based on issue/PR state
      if (!item.status) {
        item.status = this.inferStatusFromState(item.state, item.type);
      }

      // Generate default dates if missing
      this.setDefaultDates(item);

      // Calculate duration if both start and due dates are present
      if (item.startDate && item.dueDate) {
        const diffTime = item.dueDate.getTime() - item.startDate.getTime();
        item.durationDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        // Ensure minimum duration of 1 day
        if (item.durationDays < 1 || isNaN(item.durationDays)) {
          item.durationDays = 1;
        }
      } else {
        // Default duration if dates are missing
        item.durationDays = 7; // Default to 1 week
      }

      return item;
    });
  }

  /**
   * Infer epic from labels
   * @param {string[]} labels - Issue labels
   * @returns {string|null} Epic name
   */
  inferEpicFromLabels(labels) {
    const epicLabels = labels.filter(label => 
      label.toLowerCase().startsWith('epic:') || 
      label.toLowerCase().startsWith('feature:') ||
      label.toLowerCase().includes('area:')
    );
    
    if (epicLabels.length > 0) {
      return epicLabels[0].split(':')[1]?.trim() || epicLabels[0];
    }

    // Check for common epic-like labels
    const epicKeywords = ['frontend', 'backend', 'api', 'ui', 'infrastructure', 'docs', 'security'];
    for (const label of labels) {
      if (epicKeywords.some(keyword => label.toLowerCase().includes(keyword))) {
        return label.charAt(0).toUpperCase() + label.slice(1).toLowerCase();
      }
    }

    return null;
  }

  /**
   * Infer priority from labels
   * @param {string[]} labels - Issue labels
   * @returns {string|null} Priority
   */
  inferPriorityFromLabels(labels) {
    const priorityMap = {
      'priority: high': 'High',
      'priority: critical': 'Critical',
      'priority: low': 'Low',
      'high priority': 'High',
      'critical': 'Critical',
      'urgent': 'High',
      'p0': 'Critical',
      'p1': 'High',
      'p2': 'Medium',
      'p3': 'Low',
    };

    for (const label of labels) {
      const priority = priorityMap[label.toLowerCase()];
      if (priority) {
        return priority;
      }
    }

    return null;
  }

  /**
   * Infer status from issue/PR state
   * @param {string} state - GitHub state
   * @param {string} type - Item type
   * @returns {string} Status
   */
  inferStatusFromState(state, type) {
    if (state === 'CLOSED' || state === 'MERGED') {
      return 'Done';
    } else if (state === 'OPEN') {
      return type === 'pullrequest' ? 'In Review' : 'In Progress';
    } else if (state === 'DRAFT') {
      return 'In Progress';
    }
    return 'To Do';
  }

  /**
   * Set default start and due dates for items that don't have them
   * @param {Object} item - Item to process
   */
  setDefaultDates(item) {
    const now = new Date();

    // If no start date, use creation date or current date
    if (!item.startDate) {
      item.startDate = item.createdAt || now;
    }

    // If no due date, estimate based on priority and type
    if (!item.dueDate) {
      let estimatedDays = 7; // Default 1 week

      // Adjust based on priority
      switch (item.priority?.toLowerCase()) {
        case 'critical':
          estimatedDays = 3;
          break;
        case 'high':
          estimatedDays = 5;
          break;
        case 'low':
          estimatedDays = 14;
          break;
      }

      // Adjust based on estimation if available
      if (item.estimation) {
        estimatedDays = Math.max(1, Math.ceil(item.estimation * 1.5)); // 1.5 days per story point
      }

      item.dueDate = addDays(item.startDate, estimatedDays);
      item.isEstimatedDueDate = true;
    }
  }
}