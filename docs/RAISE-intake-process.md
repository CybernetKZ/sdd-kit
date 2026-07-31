https://support.cyber-net.ai/articles/VB-A-92/Podacha-zayavki-na-razrabotku-i-soobshenie-o-bage

# Подача заявки на разработку и сообщение о баге

Sub-articles
8
Add sub-article
Name
Author
Last Updated

1-EN Development Request Submission, Review, and Prioritization Process
User avatar
olga.ch
30 Jul 2026 13:37

1-RU Процесс подачи, рассмотрения и приоритизации заявок на разработку
User avatar
olga.ch
30 Jul 2026 13:38

2-EN Development Request Form
User avatar
olga.ch
30 Jul 2026 13:38

2-RU Форма запроса на разработку
User avatar
olga.ch
30 Jul 2026 13:38

3-EN GPT Agent for Creating Development Requests
User avatar
olga.ch
30 Jul 2026 13:40

3-RU GPT агент для составление заявки на разработку
User avatar
olga.ch
30 Jul 2026 13:40

4-RU Баг репорт
User avatar
olga.ch
30 Jul 2026 13:41

4-EN Bug report
User avatar
olga.ch
30 Jul 2026 14:03

---

https://support.cyber-net.ai/articles/VB-A-94/1-EN-Development-Request-Submission-Review-and-Prioritization-Process

# 1-EN Development Request Submission, Review, and Prioritization Process

Development Request Submission, Review, and Prioritization Process

1. Purpose of the Process
   This process is designed to centralize the collection, assessment, and prioritization of development requests.

It is intended to ensure:

a single standardized request format;
transparent task assessment;
comparison of tasks based on business impact and effort;
planning for the next two sprints;
timely handling of urgent tasks and bugs;
mandatory feedback to the requester on the decision made.

2. Task Categories
   All incoming tasks are divided into three categories:

2.1. Planned Development Tasks
New features, improvements, and product changes that are reviewed and prioritized using the RICE framework.

2.2. Urgent Tasks
Tasks that:

block a client launch;
create an immediate risk of losing a client.
Such tasks are reviewed outside the standard monthly cycle.

A short deadline, strong stakeholder interest, or a client request alone does not make a task urgent. To assign urgent
status, one of the following two criteria must be confirmed: the task blocks a launch or creates a genuine risk of
losing a client.

2.3. Bugs
Errors in existing functionality where the system does not behave in accordance with the agreed logic or requirements.

Bugs are not assessed or prioritized using RICE. They are registered immediately when identified and submitted using the
separate bug report template.

Bug priority is determined separately, taking into account:

issue severity;
the number of affected clients or users;
whether a workaround is available;
impact on core platform processes;
risk of data loss, call disruption, or breach of client commitments.

3. Submitting a Planned Request
   3.1. Completing the Request Form
   Before submitting a task for review, the requester must complete the development request form.

The request must include:

requester, business unit, and country;
task title;
segment;
description of the current problem;
expected outcome after implementation;
reasons for urgency, if applicable;
available supporting materials and evidence;
alternatives considered;
input data for the RICE assessment.
The task description must explain the business problem and the expected outcome. The requester is not required to design
the technical solution.

3.2. RICE Assessment
The task is assessed using four parameters:

Reach;
Impact;
Confidence;
Effort.
The final score is calculated using the following formula:

RICE Score = (Reach × Impact × Confidence) ÷ Effort

Reach and Impact must be supported by data, client cases, statistics, or other available evidence.

Effort is estimated jointly with representatives of the development team and includes the total effort required for
development, testing, integration, and any related work.

The RICE Score is used as a tool for comparing tasks, but it is not the sole basis for the decision. The following
factors are also considered:

technical dependencies;
team availability;
client commitments;
implementation risks;
need for infrastructure work;
relation to already planned initiatives;
strategic product priorities.
3.3. Creating a Ticket
Once the request form and preliminary RICE assessment have been completed, a ticket must be created on the Voicebot +
LLM board.

The ticket must include or link to:

the completed request form;
the calculated RICE Score;
supporting materials and evidence;
links to related tasks;
information about the client or business unit that submitted the request;
known dependencies and constraints.
All planned development tasks reviewed under the RICE framework must be tracked on the Voicebot + LLM board. Requests
that are not created on this board or do not contain the required information will not be included in the prioritization
process.

4. Request Validation
   Before adding a request to the shared backlog, the process owner verifies:

whether all mandatory fields are completed;
whether the problem is clearly described;
whether the expected outcome is specified;
whether supporting materials are attached;
whether Reach and Impact can be validated;
whether dependencies are listed;
whether a preliminary RICE assessment has been completed.
If the information is insufficient, the request is returned to the author for revision and is not included in the
prioritization meeting.

Returning a request for revision does not mean that it has been rejected. Once the missing information has been added,
the request may be returned to the backlog.

5. Backlog Preparation
   All requests that are ready for review are added to the shared backlog on the Voicebot + LLM board.

Before the meeting, tasks are provisionally sorted by RICE Score. The following are also flagged:

tasks with client or contractual dependencies;
tasks related to planned releases;
tasks requiring participation from multiple teams;
technical constraints;
tasks that cannot begin until other work is completed;
tasks that have already been reviewed previously.
The preliminary order does not constitute a final implementation decision.

6. Monthly Backlog Review
   The backlog review and prioritization meeting is held once a month.

The purpose of the meeting is to identify the tasks that will be taken into development during the next two sprints.

Before the meeting, participants must have access to an up-to-date list of requests containing:

problem description;
expected outcome;
RICE Score;
preliminary effort estimate;
dependencies;
additional risks and constraints.
For each request, the meeting covers:

the business problem and expected impact;
the validity of the input data;
the RICE Score;
effort;
technical dependencies;
available team capacity;
the task’s impact on already planned work;
implementation risks and the consequences of postponement.
Following the discussion, an agreed list of tasks for the next two sprints is created.

7. Possible Decisions
   One of the following decisions is made for each reviewed request.

Included in the Cycle
The task is included in the plan for the next two sprints.

The following are defined:

responsible team;
preliminary sprint;
required dependencies;
next step for requirements preparation or implementation.
Postponed
The task is considered justified but is not included in the next two sprints.

The decision must specify:

reason for postponement;
date or condition for reconsideration;
additional information that must be collected;
dependencies that must be resolved.
Returned for Revision
There is not enough information to make a decision, or additional analysis is required.

The specific questions and materials that the requester must provide are listed.

Once the request has been updated, it is returned to the backlog.

Rejected
The task is not accepted for development.

The reason must be specified, for example:

insufficiently demonstrated impact;
misalignment with product strategy;
an existing solution is already available;
the problem can be solved without development;
effort is disproportionate to the expected value;
insufficient justification for implementation.

8. Feedback to the Requester
   After the meeting, the decision is recorded in the ticket on the Voicebot + LLM board.

The requester is informed of:

the decision made;
the reason for the decision;
the responsible team, if the task is accepted;
the approximate implementation period, if determined;
the date or condition for reconsideration, if the task is postponed;
the list of required additions, if the request is returned for revision.
The requester must receive not only the task status, but also a clear explanation of the decision.

9. Review of Urgent Tasks
   Urgent tasks do not wait for the next monthly meeting.

To initiate an urgent review, the requester must confirm that the task:

blocks the launch of a specific client; or
creates an immediate risk of losing a specific client.
The request must specify:

the client;
planned launch date or critical deadline;
what exactly is blocked;
why the launch is impossible without development;
the nature of the client loss risk;
evidence of the risk, such as correspondence, a commitment, an escalation, or other available information;
whether a temporary workaround is available;
the consequences if the task is not completed by the required deadline.
Once an urgent request is submitted, an ad hoc assessment is carried out with the relevant Product and Development
representatives.

One of the following decisions is made:

confirm urgent status and include the task in development;
propose a temporary workaround;
review the task through the standard RICE process;
reject urgent status due to the absence of a confirmed blocker or client loss risk.
Assigning urgent status does not mean that development starts automatically. Before a decision is made, technical
feasibility, effort, and the impact on already planned work must be assessed.

If an urgent task is added to the current sprint, the following must be recorded:

which work is being postponed;
why the plan is being changed;
who approved the change;
how the change affects the timelines of other tasks.
The urgent task must also be created on the Voicebot + LLM board. A shortened blocker description may be used initially
if necessary, but the ticket must be completed after the decision is made.

10. Bug Handling
    A bug is registered immediately after it is identified and does not wait for the monthly backlog review.

A separate ticket must be created for each bug using the approved template.

At a minimum, the ticket must include:

description of the actual behavior;
expected behavior;
reproduction steps;
environment;
affected client or functionality;
frequency of occurrence;
available logs, screenshots, call recordings, and other supporting materials;
whether a workaround is available;
preliminary impact assessment.
After registration, the bug undergoes technical validation and severity classification.

Confirmed bugs are taken into development according to their severity and available team capacity. Critical bugs that
block platform operation, calls, a client launch, or create a risk of losing a client are reviewed out of turn.

If validation shows that the system is working in accordance with the current requirements, the request is reclassified
from a bug to a planned improvement and then goes through the standard RICE prioritization process.

11. Priority Changes
    The priority of a previously reviewed task may be changed if:

Reach or Impact changes significantly;
new validated data becomes available;
a dependency on another initiative emerges;
client commitments change;
the task starts blocking a launch or creates a risk of losing a client;
the Effort estimate changes;
a lower-effort solution becomes available.
Any priority change must be recorded in the ticket together with the reason.

12. Core Process Principles
    All planned tasks go through a single request form and RICE assessment.
    All tasks under review are created on the Voicebot + LLM board.
    Incomplete requests are not submitted for prioritization.
    The plan for the next two sprints is determined monthly.
    RICE helps compare tasks but does not replace discussion of dependencies, risks, and available resources.
    Only tasks that block a client launch or create a genuine risk of losing a client are considered urgent.
    Bugs are registered immediately and are not assessed using RICE.
    Every decision must be recorded and explained to the requester.
    Adding an urgent task to the current plan must include an explicit decision on which work will be postponed.
    All changes to status, priority, and timelines are recorded in the relevant ticket.

---

https://support.cyber-net.ai/articles/VB-A-90/2-EN-Development-Request-Form

# 2-EN Development Request Form

Prioritization using the RICE framework · Reach × Impact × Confidence ÷ Effort

This form should be completed by any commercial or country business unit before submitting a request to the development
team.

Its purpose is to provide sufficient context for an informed prioritization decision without the need for additional
follow-up questions.

1. General Information
   Requester / business unit / country Who is submitting the request and on whose behalf
   Business unit For example, Telemarketing
   Country Kazakhstan, Mexico, all countries of operation
   Task title One line describing the essence of the request, without implementation details
   Segment Debt Relief / Collections / Customer Service / Other
   Current problem What happens without this functionality — 2–3 sentences. A specific use case is better than a general
   statement.
   Expected change How the process, customer experience, or agent workflow will work after implementation — 2–3
   sentences.
   Urgency and rationale Regulatory deadline / contractual commitment to a customer / risk of losing a customer /
   competitive pressure / no urgency
   Do competitors offer this? Optional: who already offers it and how it works, with a link or example.
   Supporting materials Call recordings, customer correspondence, screenshots, or anything else that can speed up
   understanding and reduce follow-up questions.
   Alternatives considered What other options were considered and why this option was selected, including the option of
   doing nothing.
2. RICE Assessment
   To be completed jointly with the Product team and/or Tech Lead.

Final score = (Reach × Impact × Confidence) ÷ Effort. The higher the score, the higher the priority.

Parameter Value How to assess it
Reach How many entities will be affected during a given period, for example customers, calls, or agents per month or
quarter.
Impact The strength of the effect on one entity: 3 / 2 / 1 / 0.5 / 0.25. See the scale below.
Confidence How confident we are in the Reach and Impact estimates: 100% / 80% / 50%. See the scale below.
Effort Total effort in person-months, including development, QA, and integration.
RICE Score = (Reach × Impact × Confidence) ÷ Effort
Impact Reference Scale

Score Definition
3 Massive impact — critically changes a product or business outcome
2 High impact
1 Medium impact
0.5 Low impact
0.25 Minimal impact
Confidence Reference Scale

Score Definition
100% High confidence — supported by data or measurements; estimates are reliable
80% Medium confidence — there is a reasonable basis, but some assumptions remain
50% Low confidence — largely a hypothesis or “moonshot”

3. Decision
   Owner

The team responsible for taking the task

Decision

Included in the delivery cycle / postponed, with a review date / rejected, with a reason

Date the requester was informed

The requester receives both the decision and its rationale, not just confirmation that the request has been added to the
queue.

---
https://support.cyber-net.ai/articles/VB-A-95/3-EN-GPT-Agent-for-Creating-Development-Requests

# 3-EN GPT Agent for Creating Development Requests

For convenience, you can use the agent to prepare the request and attach the completed form to the ticket.
https://chatgpt.com/g/g-6a68646b7d8881919e574226ee0ca352-rice-request-builder

---

https://support.cyber-net.ai/articles/VB-A-96/4-EN-Bug-report

# 4-EN Bug report

Environment: dev/stage/prod

Type: inbound/outbound/chat

Agent: agent name

Priority: low/medium/high/critical

Low — a minor issue or improvement request. Does not affect business logic or calls. Examples: an unclear button in the
admin interface, a missing tooltip, a typo, or incorrect spacing.
Medium — the issue affects a specific function but does not block the system as a whole. A workaround exists, or the
issue occurs only in some cases. Examples: the agent repeats the same phrase in a rare scenario; ASR misrecognizes some
phrases on a noisy line; call reports update with a delay; RAG occasionally returns outdated answers; a CRM notification
is not sent, but calls continue.
High — a serious issue affecting key functionality and significantly degrading the user experience. No simple workaround
is available. Examples: the dashboard does not update; some outbound calls are not initiated; TTS stops voicing
responses after several turns; the agent cannot complete the scenario.
Critical — the issue completely blocks the system or clients. Examples: telephony is unavailable; the platform is
unresponsive; inbound or outbound calls do not go through; the API returns 500 errors for all requests.
Dialogue ID: in the format 55cf3be6-a570-4146-9a0e-fbc4b844210b

Problem: describe the issue in detail. Attach screenshots if needed. Include the steps required to reproduce the bug,
using the template below if necessary.

Correct examples:

ASR did not recognize the customer’s second utterance.
After being asked to speak Russian, the robot did not switch to another language.
The call was not transferred to an operator, even though the expected robot behavior is described in the prompt and the
call transfer function is configured.
The robot used the wrong greeting, even though the agent settings specify that the robot should greet first and a
greeting is configured.
Incorrect examples:

Incorrect robot greeting.
Recognition error.
Nothing works.
Steps:

Place an outbound call to the client.
Wait for the agent’s greeting.
Respond in Russian.
Actual result: the agent remains silent for 10 seconds and then ends the call.

Expected result: the agent should respond to the customer’s utterance.
