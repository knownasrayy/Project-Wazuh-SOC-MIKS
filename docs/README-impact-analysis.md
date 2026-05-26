# Impact Analysis Documentation

## Overview
This directory contains the **Impact Analysis** template and guidelines. An Impact Analysis is a critical component of the Incident Response lifecycle. It helps security analysts and stakeholders understand the full consequences of a security incident.

## Purpose
The primary purpose of the Impact Analysis is to evaluate and document how a security incident affects the organization in three main areas:
1. **Business Functions:** The effect on revenue, daily operations, productivity, and service availability.
2. **Operations:** The technical consequences, such as data loss, system degradation, and the effort required for recovery.
3. **Reputation & Legal:** The external consequences, including brand damage, loss of customer trust, regulatory fines, and legal liabilities.

## How to Use the Template
1. Open the [impact-analysis.md](impact-analysis.md) file.
2. Copy the contents to create a new report for a specific incident (e.g., `impact-analysis-INC-2023-001.md`).
3. Fill out each section with accurate details gathered during the post-incident review phase.
4. Share the completed report with relevant stakeholders (Management, Legal, PR, and IT teams) to ensure a coordinated response and proper mitigation planning.

## Integration with Wazuh and Azure
When responding to incidents detected by **Wazuh** within our **Azure** infrastructure:
- Use Wazuh logs and alerts to determine the scope of affected assets (Operational Impact).
- Correlate Azure metrics (e.g., CPU spikes, network traffic anomalies) to quantify downtime or service disruption (Business Functions Impact).
- Use the Impact Analysis report to justify future security investments or rule tuning in the Wazuh Manager.
