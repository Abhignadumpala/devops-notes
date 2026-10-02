# Day 1 - SDLC, Waterfall, Agile & Why DevOps

## Table of Contents

1. [Who Are Stakeholders?](#who-are-stakeholders)
2. [SDLC - Software Development Life Cycle](#sdlc---software-development-life-cycle)
3. [Waterfall Model](#waterfall-model)
4. [Agile Model](#agile-model)
5. [Waterfall vs Agile - Restaurant App Example](#waterfall-vs-agile---restaurant-app-example)
6. [Why Multiple Environments?](#why-multiple-environments)
7. [Agile with DevOps](#agile-with-devops)
8. [What Problems DevOps Solves](#what-problems-devops-solves)
9. [How to Bring Improvements into a Company](#how-to-bring-improvements-into-a-company)
10. [Summary](#summary)
11. [Interview Questions](#interview-questions)

---

## Who Are Stakeholders?

**Stakeholders = everyone who is part of a system or affected by it.** A good system keeps all of them happy.

| System | Stakeholders |
|--------|--------------|
| Family | Parents, us, our kids, relatives, friends, society, colleagues |
| Bank | Customers, employees, management & leadership, investors, RBI, IT, marketing, sales, operations, security, admin teams, partners |
| School | Students, teaching staff, non-teaching staff, leadership, investors, education department |
| DevOps | Team members, management, developers, testing team, operations team, admin team |

> A company with 100 customers can manage without formal processes. At 1 crore customers, you **need a proper process** - that's where SDLC and DevOps come in.

Two perspectives always matter:
- **Client perspective** - the one paying for the software
- **End-user perspective** - the one using the software

---

## SDLC - Software Development Life Cycle

SDLC is the step-by-step process to build software.

### House Construction Analogy

| # | SDLC Phase | House Construction | Software |
|---|------------|--------------------|----------|
| 1 | Requirements Gathering | No. of bedrooms, budget, etc. | Features the client wants |
| 2 | Planning & Analysis | Analyse the requirements | Analyse client requirements, timelines, cost |
| 3 | Design | House plan | Architecture, UI design |
| 4 | Development | Construction | Writing code |
| 5 | Testing | Check it matches the plan | Find defects |
| 6 | Deployment | Start living in the house | Release to users |
| 7 | Maintenance | Modifications | Bug fixes, new features |

```text
Requirements → Planning → Design → Development → Testing → Deployment → Maintenance
```

---

## Waterfall Model

Each phase is done **once**, one after another. **You can't go back.**

### School Example - Gurukul (Waterfall)

- Only **one exam** at year end (e.g. June 1st) - only one chance.
- From Day 1, students and teachers are not serious. Only parents are.
- Result: out of 100 students, only 20-30 pass, **70% fail**.

### Problems with Waterfall

- Defects found only at the end
- Fixing late is costly
- Client sees the product only at the end
- One big release = high risk

---

## Agile Model

Work is split into **small pieces (sprints)**. Each piece is developed, tested and delivered, then the next one starts.

### School Example - Unit Tests (Agile)

- Unit Test I, II, III, IV → Quarterly → Half-yearly → Grand Test → Final
- Parents (clients) see progress after every test.
- Student improves every time:

| Test | Marks |
|------|-------|
| Unit Test I | 30 (failed) |
| Unit Test II | 31 |
| Final | 36 (passed) |

- Result: out of 100 students, **90 pass**.

### Mapping

| School | Software |
|--------|----------|
| Students | Developers, IT team |
| Parents | Clients |
| Teachers | Testing team |
| Gurukul (one final exam) | Waterfall |
| Unit tests | Agile |

### More Testing = Fewer Defects

| Times Tested | Defects Left |
|--------------|--------------|
| Once | Looks like no defects (not really tested) |
| 10 times | 1 defect found |
| 1000 times | 2 defects found and fixed |

Testing often (daily/slip tests) catches defects early.

---

## Waterfall vs Agile - Restaurant App Example

### Waterfall (1 Year)

Team: developers, testing team, build & release team, management.

| Phase | Time |
|-------|------|
| Discussions only | 3-4 months |
| Development | 3 months |
| Testing | 2 months |

- Testing finds **100 defects**, sent back to developers.
- 20 of them are invalid defects.
- Only then the final product is delivered.

### Agile (Monthly Sprints)

Each module is one sprint (~1 month):

| Sprint | Module |
|--------|--------|
| 1 | Sign up & Sign in |
| 2 | Products catalogue (+ fix previous sprint's defects) |
| 3 | Cart |
| 4 | Order management |
| 5 | Payment |
| 6 | Tracking |
| 7 | Delivery |

Each sprint:
- Development → 2 weeks
- Testing & deployment → 2 weeks

Result: fewer defects (e.g. 15 invalid instead of 20), and the client sees working features every month. The final product is complete and polished (like a Honda City, not a half-built car).

---

## Why Multiple Environments?

Before releasing to everyone, test in stages.

### Cooking Analogy

| Stage | Who Tastes |
|-------|------------|
| 1 | We taste it ourselves |
| 2 | Family members |
| 3 | Friends and relatives |
| 4 | Small crowd |
| 5 | Everyone (market release) |

### Software Environments

| Environment | Full Name | Purpose |
|-------------|-----------|---------|
| DEV | Development | Developers test their code |
| SIT | System Integration Testing | Test all modules together |
| UAT | User Acceptance Testing | Client/business verifies |
| PRE-PROD | Pre-Production | Exact copy of production for final check |
| PERF | Performance | Load and speed testing |
| SEC | Security | Security testing |
| PROD | Production | Real users |

A new product doesn't capture the market in one go - it starts small (e.g. 10% market share against a giant like Coca-Cola) and grows by improving with every release.

---

## Agile with DevOps

Agile alone releases every month. **DevOps makes it daily.**

Example - Sign up & Sign in sprint:

**Day 1:** Developer builds:
```text
Enter your first name ___________
Enter your last name  ___________
```
It's built, deployed and tested the same day.

**Day 2:** 10 defects found, 1 invalid → fixed immediately.

### Types of Test Cases

| Type | Input | Expected Result |
|------|-------|-----------------|
| Positive | Valid inputs | Success |
| Negative | Invalid inputs | Proper failure/error |

### Who Does What

**Build and release** (building code, deploying to DEV/SIT/UAT/PROD) is handled by the **DevOps process and DevOps team**, using automation.

---

## What Problems DevOps Solves

| Problem | DevOps Solution |
|---------|-----------------|
| Slow releases (months) | **Faster releases** (daily/weekly) via automation |
| Defects found late | **Fewer defects** - test continuously |
| Manual, error-prone deployments | Automated build & release (CI/CD) |
| App goes down | **High availability** |
| Traffic spikes | **Auto scaling** |
| Attacks and leaks | **Security** built into the process |
| Wasted servers and money | **Cost optimisation** |

Competition example: WhatsApp vs Arattai - the app that ships features and fixes faster wins users.

---

## How to Bring Improvements into a Company

1. Understand their current process
2. Work with that process
3. Find improvements
4. Do a simple **POC** (Proof of Concept) - prove it works
5. Implement in DEV, SIT, UAT
6. Take it to PROD

---

## Summary

- **Stakeholders** = everyone affected by the system.
- **SDLC** = Requirements → Planning → Design → Development → Testing → Deployment → Maintenance.
- **Waterfall** = one pass, can't go back, defects found late.
- **Agile** = small sprints, continuous feedback.
- **DevOps** = Agile + automation → faster releases, fewer defects, highly available, scalable, secure, cost-optimised.

---

## Interview Questions

12 questions with short answers → [interview-questions/](interview-questions/README.md)
