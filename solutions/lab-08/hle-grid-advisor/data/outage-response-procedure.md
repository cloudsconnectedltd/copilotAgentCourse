<!-- Plain-text extract of data/sharepoint/Harbourline-Operations/Procedures/Outage-Response-Procedure.docx (OPS-PRO-001 Rev 7) for HLE Grid Advisor retrieval. Headings start with '## '. Regenerate if the source document changes. -->
Harbourline Energy Co.
Outage Response Procedure
| Field | Value |
| Document ID | OPS-PRO-001 |
| Revision | 7 |
| Effective date | March 1, 2026 |
| Next review | March 1, 2027 |
| Document owner | Renata Okafor, Director, Distribution Operations |
| Approved by | Graham Lindqvist, Vice President, Operations |
| Applies to | All Harbourline distribution regions in Ontario, New York and Ohio |

## 1. Purpose
This procedure defines how Harbourline Energy Co. classifies, escalates, communicates and restores unplanned electric service interruptions on its distribution system. It sets the outage severity levels L1 to L4, the notification timelines for each level, the responsibilities of the Distribution System Operator, the Storm Coordinator and Customer Communications, and the order in which customers and facilities are restored.
The procedure supports Harbourline's obligations to the Ontario Energy Board (OEB), the New York State Public Service Commission (NY PSC) and the Public Utilities Commission of Ohio (PUCO), and supports event reporting obligations under NERC reliability standards for the transmission facilities Harbourline operates.
## 2. Scope
This procedure applies to every unplanned interruption on Harbourline distribution feeders, laterals and secondary services, and to transmission supply interruptions that affect Harbourline customers. It does not apply to planned outages, which follow OPS-PRO-004 Planned Outage Notification.
| Operating region | Control centre | Approximate customers served |
| Eastern Ontario (Kingston, Napanee, Brockville) | Kingston Distribution Control Centre | 148,000 |
| Central Ontario (Barrie, Orillia, Midland) | Barrie Distribution Control Centre | 162,000 |
| Durham (Whitby, Oshawa, Port Perry) | Barrie Distribution Control Centre | 101,000 |
| New York North Country (Watertown, Canton) | Watertown Distribution Control Centre | 71,000 |
| Western New York (Jamestown, Dunkirk) | Watertown Distribution Control Centre | 57,000 |
| Northeast Ohio (Ashtabula, Painesville) | Mansfield Distribution Control Centre | 52,000 |
| North Central Ohio (Mansfield, Ashland) | Mansfield Distribution Control Centre | 44,000 |

## 3. Definitions
Outage Management System (OMS): the GridView OMS application that predicts outage devices from customer calls and smart meter last gasp messages and tracks every outage event from creation to closure.
Customers out: the count of metered service points without supply as reported by OMS at a point in time.
Estimated Time of Restoration (ETR): the time by which Harbourline expects supply to be restored to a customer, published on the outage map and in customer notifications.
Critical facility: a hospital, long term care home, water or wastewater treatment plant or pumping station, 911 call centre, police, fire or EMS station, or other site listed in the Critical Facilities Register maintained by each region.
Life support customer: a residential customer registered with Harbourline as relying on electrically powered medical equipment.
Emergency Operations Centre (EOC): a Regional EOC is staffed in the affected region's control centre; the Corporate EOC is staffed at the Toronto head office, 200 Front Street West.
## 4. Roles and Responsibilities
| Role | Primary responsibilities | Backup |
| Distribution System Operator (DSO) | Monitors SCADA and OMS 24/7. Confirms the outage, declares the initial severity level, performs remote switching to isolate faults and restore unfaulted sections, dispatches the first responder, and makes the first internal notification. | Senior DSO on shift |
| Storm Coordinator | On call 24/7 on a weekly rotation. Owns resource allocation for L2 and above: assigns crews, calls out additional line and forestry crews, requests contractor and mutual assistance resources, sets restoration sequence within the priority order in Section 7, and confirms or changes the severity level. | Regional Operations Manager |
| Customer Communications | Publishes outage map updates, social media posts, news releases and ETR messages; contacts critical facilities and life support customers; briefs the contact centre with approved scripts. | Corporate Communications Duty Manager |
| Regional Operations Manager | Leads the Regional EOC at L3 and above, approves overtime extensions and contractor spend. | Director, Distribution Operations |
| Regulatory Affairs | Determines whether an event triggers a reporting obligation to the OEB, NY PSC or PUCO, and files it. | Manager, Regulatory Compliance |

## 5. Outage Severity Levels
The DSO declares the initial level as soon as an outage is confirmed. The level is based on the peak number of customers out system wide at the time of assessment, or on any of the other triggers in the table, whichever gives the higher level. Only the Storm Coordinator can lower a level.
| Level | Name | Customers out | Other triggers | Declared by |
| L1 | Minor | 1 to 499 | Single transformer, tap or lateral; ETR 4 hours or less | DSO |
| L2 | Elevated | 500 to 4,999 | Any critical facility out; any feeder breaker lockout; ETR more than 4 hours | DSO |
| L3 | Major | 5,000 to 49,999 | Three or more feeder lockouts in one region; more than 1,000 customers with projected outage over 24 hours | DSO, confirmed by Storm Coordinator |
| L4 | Emergency | 50,000 or more | Loss of a transformer station or substation supply serving more than 20,000 customers; government emergency declaration in a service territory | Storm Coordinator, confirmed by VP Operations |

## 6. Notification Timelines
Timelines are measured from the time the level is declared. Every notification is logged in the OMS event record with the time, the person notified and the method (phone, Teams, email).
| Level | Internal notification | Customer communications | Regulatory |
| L1 | DSO logs event in OMS within 15 minutes. No escalation. | Outage map updates automatically within 15 minutes. | None. |
| L2 | DSO notifies the on call Storm Coordinator within 30 minutes. | Customer Communications posts on social media within 30 minutes and refreshes every 2 hours. Critical facility contact within 30 minutes. | None unless a critical facility is out more than 8 hours. |
| L3 | Storm Coordinator notifies the Director, Distribution Operations and the VP Operations within 60 minutes. Regional EOC activated within 2 hours. | News release within 2 hours, updates every 4 hours. Life support customers contacted within 6 hours. | Regulatory Affairs notified within 4 hours to assess reporting obligations. |
| L4 | VP Operations notifies the CEO within 1 hour. Corporate EOC activated within 1 hour. | News release within 1 hour, updates every 3 hours. Life support customers contacted within 4 hours. | Regulatory Affairs notified within 1 hour. Transmission Operations assesses NERC EOP-004 event reporting within 24 hours. |

## 7. Restoration Priority Order
Within each region, restoration work is sequenced in the following order. The Storm Coordinator may depart from the order only to remove an immediate hazard to life, and must record the reason in OMS.
Step 1. Public safety hazards: energized wires down, fires, and requests from police or fire services to make safe.
Step 2. Hospitals and long term care homes.
Step 3. Water and wastewater treatment plants and water pumping stations.
Step 4. 911 call centres, police, fire and EMS stations.
Step 5. Registered life support customers.
Step 6. Transmission lines, transformer stations and substations, then feeder mainlines that restore the largest number of customers per crew hour.
Step 7. Telecommunications hubs, fuel distribution sites, and designated warming or cooling centres.
Step 8. Taps and laterals, largest customer count first.
Step 9. Individual services and secondary connections.
## 8. Response Workflow
## 8.1 Detection and confirmation
OMS creates an outage event from smart meter last gasp messages, SCADA breaker operations or customer calls. The DSO confirms the event by SCADA indication, meter ping or a first responder report, and declares the level. Unconfirmed predicted outages older than 30 minutes are reviewed by the senior DSO.
## 8.2 First response
The DSO dispatches the nearest trouble crew. The first responder makes the site safe, patrols the affected section, reports damage in the mobile workforce application and gives the DSO an initial assessment within 60 minutes of arrival.
## 8.3 Isolation and partial restoration
The DSO uses remote switching and field switching to isolate the faulted section and restore unfaulted sections. All field switching follows OPS-PRO-006 Substation and Distribution Switching Procedure. Work on isolated equipment requires a lockout under SAF-MAN-002.
## 8.4 Resource escalation
At L2 and above the Storm Coordinator reviews resource needs every 2 hours. At L3 and above the Storm Coordinator follows OPS-PLB-004 Storm Restoration Playbook for staging, contractor call out and mutual assistance.
## 8.5 Close out
An event is closed in OMS only when every customer in the event is confirmed restored by meter ping or field confirmation, and the cause code, equipment and crew time are recorded.
## 9. Estimated Time of Restoration Standards
L1 and L2: an initial ETR is published within 60 minutes of the first responder's assessment.
L3: a regional ETR is published within 8 hours of the level declaration.
L4: a global ETR (for example, 90 percent of customers restored by a stated time) is published within 12 hours of the level declaration.
An ETR that will be missed is updated at least 30 minutes before it expires.
## 10. Escalation and De-escalation
The level is raised immediately when any trigger for a higher level is met. The Storm Coordinator may lower the level when customers out have been below the threshold of the current level for 2 consecutive hours and no new triggers are active. EOCs are stood down by the person who activated them.
## 11. Post-Event Review
L2: crew debrief recorded in OMS within 10 business days.
L3 and L4: an After Action Report is issued within 30 calendar days by the Regional Operations Manager (L3) or the Director, Distribution Operations (L4).
Any missed notification timeline is reported to the Director, Distribution Operations within 5 business days.
## 12. Records
OMS event records, notification logs and After Action Reports are retained for 7 years.
## 13. Related Documents
OPS-PLB-004 Storm Restoration Playbook
OPS-PRO-006 Substation and Distribution Switching Procedure
SAF-MAN-002 Lockout and Tagout Safety Manual
OPS-PRO-004 Planned Outage Notification
## Revision History
| Revision | Date | Author | Summary of changes |
| 5 | 2023-02-10 | R. Okafor | Added Ohio regions after service territory transfer. |
| 6 | 2024-11-04 | R. Okafor | Added life support customer contact timelines. |
| 7 | 2026-03-01 | R. Okafor | L2 threshold changed from 250 to 500 customers; added Durham region. |

