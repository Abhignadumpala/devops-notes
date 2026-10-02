# Day 1 - Interview Questions

[← Back to Day 1 notes](../README.md)

**1. What is SDLC? Name the phases.**

Software Development Life Cycle - the step-by-step process to build software: Requirements → Planning & Analysis → Design → Development → Testing → Deployment → Maintenance.

**2. Difference between Waterfall and Agile?**

Waterfall runs each phase once in sequence; you can't go back, and defects show up only at the end. Agile splits work into short sprints; each sprint is built, tested and delivered, so feedback comes early and changes are cheap.

**3. What is a sprint?**

A fixed short period (usually 2-4 weeks) in which a small set of features is developed, tested and delivered.

**4. What is DevOps?**

A culture and set of practices that brings Development and Operations together and automates build, test and deployment, so software is released faster, more often and more reliably.

**5. What problems does DevOps solve?**

Slow releases, late defects, manual error-prone deployments, downtime, poor scaling, security gaps and wasted cost. DevOps fixes these with automation (CI/CD), continuous testing, high availability, auto scaling, built-in security and cost optimisation.

**6. What is CI/CD?**

**CI (Continuous Integration)** - every code change is automatically built and tested. **CD (Continuous Delivery/Deployment)** - every successful build is automatically delivered to environments (and to production in continuous deployment).

**7. Why do we need multiple environments? Name them.**

To catch problems step by step before real users see them. DEV → SIT → UAT → PRE-PROD → PERF → SEC → PROD.

**8. Difference between SIT and UAT?**

SIT (System Integration Testing) checks that all modules work together - done by the testing team. UAT (User Acceptance Testing) checks the software meets business needs - done by the client/business users.

**9. What is PRE-PROD?**

An exact copy of production used for the final check before release.

**10. Positive vs negative test cases?**

Positive: valid input, expect success. Negative: invalid input, expect a proper error (not a crash).

**11. Who are stakeholders?**

Everyone who is part of or affected by the system - clients, end users, developers, testers, operations, management, investors, regulators.

**12. How would you introduce a new tool or process in a company?**

Understand the current process → work with it → find improvements → build a small POC to prove it → roll out in DEV, SIT, UAT → then PROD.
