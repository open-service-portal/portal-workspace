/**
 * @typedef {Object} ProjectItem
 * @property {string} id - The item ID
 * @property {Object} content - The content object (Issue or PullRequest)
 * @property {string} content.title - The title
 * @property {string} content.url - The URL
 * @property {string} content.state - The state (OPEN, CLOSED, etc.)
 * @property {Object[]} content.assignees - Array of assignees
 * @property {Object[]} content.labels - Array of labels
 * @property {string} [content.createdAt] - Creation date
 * @property {string} [content.closedAt] - Closed date
 * @property {Object[]} fieldValues - Array of custom field values
 */

/**
 * @typedef {Object} FieldValue
 * @property {string} __typename - The field type
 * @property {Object} field - The field definition
 * @property {string} field.name - The field name
 * @property {string} [name] - For SingleSelect fields
 * @property {string} [text] - For Text fields
 * @property {string} [date] - For Date fields
 * @property {number} [number] - For Number fields
 * @property {Object} [milestone] - For Milestone fields
 */

/**
 * @typedef {Object} ProcessedItem
 * @property {string} id - The item ID
 * @property {string} title - The title
 * @property {string} url - The URL
 * @property {string} state - The state
 * @property {string} type - The type (issue, pullrequest)
 * @property {string[]} labels - Array of label names
 * @property {string[]} assignees - Array of assignee logins
 * @property {string} [epic] - Epic name from custom field
 * @property {string} [priority] - Priority from custom field
 * @property {string} [status] - Status from custom field
 * @property {Date} [startDate] - Start date from custom field
 * @property {Date} [dueDate] - Due date from custom field
 * @property {Date} createdAt - Creation date
 * @property {Date} [closedAt] - Closed date
 * @property {number} [estimation] - Story points or estimation
 * @property {string[]} dependencies - Array of dependent item IDs
 */

/**
 * @typedef {Object} GanttConfig
 * @property {string} title - Chart title
 * @property {string} dateFormat - Date format for Mermaid
 * @property {string} axisFormat - Axis format for display
 * @property {Object.<string, string>} colors - Color mapping for different states
 * @property {string[]} sections - Ordered list of section names
 */

export {};