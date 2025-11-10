import { graphql } from '@octokit/graphql';
import chalk from 'chalk';
import { execSync } from 'child_process';

/**
 * GitHub GraphQL client for Projects v2 API
 */
export class GitHubClient {
  constructor(token) {
    // Support empty token to use gh cli
    let actualToken = token;
    if (!token || token === 'use-gh-cli') {
      try {
        actualToken = execSync('gh auth token', { encoding: 'utf-8' }).trim();
        console.log(chalk.green('✅ Using GitHub CLI token'));
      } catch (error) {
        throw new Error('Failed to get GitHub CLI token. Run: gh auth login or set GITHUB_TOKEN');
      }
    }
    
    this.graphql = graphql.defaults({
      headers: {
        authorization: `bearer ${actualToken}`,
      },
    });
  }

  /**
   * Get project information including custom fields
   * @param {string} organization - Organization name
   * @param {number} projectNumber - Project number
   * @returns {Promise<Object>} Project data with fields
   */
  async getProject(organization, projectNumber) {
    console.log(chalk.blue(`🔍 Fetching project ${projectNumber} from ${organization}...`));

    const query = `
      query($organization: String!, $projectNumber: Int!) {
        organization(login: $organization) {
          projectV2(number: $projectNumber) {
            id
            title
            shortDescription
            readme
            url
            fields(first: 20) {
              nodes {
                __typename
                ... on ProjectV2Field {
                  id
                  name
                  dataType
                }
                ... on ProjectV2SingleSelectField {
                  id
                  name
                  dataType
                  options {
                    id
                    name
                    color
                  }
                }
                ... on ProjectV2IterationField {
                  id
                  name
                  dataType
                  configuration {
                    iterations {
                      id
                      title
                      startDate
                      duration
                    }
                  }
                }
              }
            }
          }
        }
      }
    `;

    try {
      const result = await this.graphql(query, {
        organization,
        projectNumber,
      });

      if (!result.organization?.projectV2) {
        throw new Error(`Project ${projectNumber} not found in organization ${organization}`);
      }

      console.log(chalk.green(`✅ Found project: ${result.organization.projectV2.title}`));
      return result.organization.projectV2;
    } catch (error) {
      console.error(chalk.red(`❌ Error fetching project: ${error.message}`));
      throw error;
    }
  }

  /**
   * Get all items from a project with their field values
   * @param {string} projectId - Project node ID
   * @param {number} first - Number of items to fetch (default: 100)
   * @returns {Promise<Object[]>} Array of project items with field values
   */
  async getProjectItems(projectId, first = 100) {
    console.log(chalk.blue(`📋 Fetching project items...`));

    const query = `
      query($projectId: ID!, $first: Int!) {
        node(id: $projectId) {
          ... on ProjectV2 {
            items(first: $first) {
              nodes {
                id
                type
                fieldValues(first: 20) {
                  nodes {
                    __typename
                    ... on ProjectV2ItemFieldTextValue {
                      field {
                        __typename
                        ... on ProjectV2FieldCommon {
                          id
                          name
                        }
                      }
                      text
                      id
                      updatedAt
                    }
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      field {
                        __typename
                        ... on ProjectV2FieldCommon {
                          id
                          name
                        }
                      }
                      name
                      id
                      updatedAt
                      optionId
                    }
                    ... on ProjectV2ItemFieldDateValue {
                      field {
                        __typename
                        ... on ProjectV2FieldCommon {
                          id
                          name
                        }
                      }
                      date
                      id
                      updatedAt
                    }
                    ... on ProjectV2ItemFieldNumberValue {
                      field {
                        __typename
                        ... on ProjectV2FieldCommon {
                          id
                          name
                        }
                      }
                      number
                      id
                      updatedAt
                    }
                    ... on ProjectV2ItemFieldMilestoneValue {
                      field {
                        __typename
                        ... on ProjectV2FieldCommon {
                          id
                          name
                        }
                      }
                      milestone {
                        id
                        title
                        description
                        dueOn
                        state
                      }
                    }
                    ... on ProjectV2ItemFieldIterationValue {
                      field {
                        __typename
                        ... on ProjectV2FieldCommon {
                          id
                          name
                        }
                      }
                      title
                      startDate
                      duration
                    }
                  }
                }
                content {
                  __typename
                  ... on Issue {
                    id
                    title
                    url
                    state
                    createdAt
                    closedAt
                    number
                    body
                    assignees(first: 10) {
                      nodes {
                        login
                        name
                      }
                    }
                    labels(first: 20) {
                      nodes {
                        name
                        color
                      }
                    }
                    milestone {
                      id
                      title
                      description
                      dueOn
                      state
                    }
                  }
                  ... on PullRequest {
                    id
                    title
                    url
                    state
                    createdAt
                    closedAt
                    mergedAt
                    number
                    body
                    assignees(first: 10) {
                      nodes {
                        login
                        name
                      }
                    }
                    labels(first: 20) {
                      nodes {
                        name
                        color
                      }
                    }
                  }
                  ... on DraftIssue {
                    id
                    title
                    body
                    assignees(first: 10) {
                      nodes {
                        login
                        name
                      }
                    }
                  }
                }
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        }
      }
    `;

    try {
      const result = await this.graphql(query, {
        projectId,
        first,
      });

      const items = result.node?.items?.nodes || [];
      console.log(chalk.green(`✅ Retrieved ${items.length} project items`));

      // TODO: Handle pagination if hasNextPage is true
      if (result.node?.items?.pageInfo?.hasNextPage) {
        console.log(chalk.yellow(`⚠️  More items available - pagination not yet implemented`));
      }

      return items;
    } catch (error) {
      console.error(chalk.red(`❌ Error fetching project items: ${error.message}`));
      throw error;
    }
  }

  /**
   * Get organization projects list (for debugging/discovery)
   * @param {string} organization - Organization name
   * @returns {Promise<Object[]>} Array of projects
   */
  async getOrganizationProjects(organization) {
    console.log(chalk.blue(`🏢 Fetching projects from ${organization}...`));

    const query = `
      query($organization: String!) {
        organization(login: $organization) {
          projectsV2(first: 20) {
            nodes {
              id
              number
              title
              shortDescription
              url
              closed
              visibility
            }
          }
        }
      }
    `;

    try {
      const result = await this.graphql(query, {
        organization,
      });

      const projects = result.organization?.projectsV2?.nodes || [];
      console.log(chalk.green(`✅ Found ${projects.length} projects`));
      
      projects.forEach(project => {
        console.log(chalk.gray(`  - #${project.number}: ${project.title} (${project.visibility})`));
      });

      return projects;
    } catch (error) {
      console.error(chalk.red(`❌ Error fetching organization projects: ${error.message}`));
      throw error;
    }
  }
}