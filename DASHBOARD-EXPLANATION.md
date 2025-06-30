# 📊 Complete SRE Dashboard Guide

## 🎯 Your 4 Dashboards Explained

---

## 📊 **Dashboard 1: SRE Shop - SLO Dashboard**
*Primary dashboard for daily SRE health checks*

### 📈 **Availability SLI**
**What it shows:** Service uptime percentage - how often your backend is accessible
- 🟢 **GOOD:** 99.9% or higher (green) - Excellent service reliability!
- 🟡 **WARNING:** 99-99.9% (yellow) - Some issues, monitor closely
- 🔴 **CRITICAL:** Below 99% (red) - Service having serious problems

**Target:** 99.9% uptime (allows ~8.7 hours downtime per year)

### ✅ **Success Rate SLI**
**What it shows:** Percentage of successful HTTP requests
- 🟢 **GOOD:** 99.9% or higher - Almost all requests succeed
- 🟡 **WARNING:** 99.5-99.9% - Some errors occurring  
- 🔴 **CRITICAL:** Below 99.5% - Many requests failing

**Target:** 99.9% success rate (only 0.1% errors allowed)

### 💻 **CPU Usage**
**What it shows:** How much CPU your backend applications are using
- 🟢 **GOOD:** 0-50% - Plenty of capacity available
- 🟡 **WARNING:** 50-80% - Getting busy, watch closely
- 🔴 **CRITICAL:** Above 80% - Running hot, may slow down

**Target:** Below 50% usage for healthy operation

### ⏱️ **Error Budget**
**What it shows:** How much of your "allowed downtime" you've used up
- 🟢 **GOOD:** 0-50% - Plenty of error budget remaining
- 🟡 **WARNING:** 50-75% - Using up your allowance
- 🔴 **CRITICAL:** 75%+ - Almost out of error budget!

**Explanation:** If you have 99.9% uptime target, you're "allowed" 0.1% downtime per month

### 📈 **Availability Trend**
**What it shows:** Service availability over the last 24 hours
- **Healthy:** All lines stay at 1.0 (100% available)
- **Problems:** Lines drop below 1.0 or show gaps
- **Red Target Line:** Shows your 99.9% SLO target

### 🔍 **Backend Pod Health Status**
**What it shows:** Health of each individual backend pod
- **1:** Pod is healthy and running
- **0:** Pod is down, crashed, or unhealthy
- **Good:** All lines at 1.0
- **Bad:** Any line drops to 0

### 📊 **HTTP Request Rate**
**What it shows:** Number of HTTP requests per second to your backend
- **Normal:** ~3 req/sec from traffic generators
- **Higher:** More traffic (could be load testing or real users)
- **Zero:** No traffic - potential problem

---

## 🚦 **Dashboard 2: SRE Shop - Traffic Dashboard**
*Monitor HTTP traffic patterns and performance*

### 🚀 **Current Request Rate**
**What it shows:** Live number showing requests per second right now
- **Normal:** ~3 req/sec from traffic generators
- **Higher:** Increased load or traffic spikes
- **Lower/Zero:** Potential connectivity issues

### 📈 **Request Rate Over Time**
**What it shows:** Graph of request rate trends over the last 15 minutes
- **Steady line:** Consistent traffic (good)
- **Spikes:** Traffic bursts
- **Flat at zero:** Service not receiving requests

### 💾 **Backend Memory Usage**
**What it shows:** Memory consumption by backend in megabytes (MB)
- 🟢 **GOOD:** <100MB - Efficient memory usage
- 🟡 **WARNING:** 100-500MB - Higher memory consumption
- 🔴 **CRITICAL:** >500MB - High memory usage, potential leak

### 📊 **Request Details by Status Code**
**What it shows:** Breakdown of HTTP responses by status code
- **200:** Successful requests (good)
- **404:** Not found errors (could be normal or bad)
- **500:** Server errors (bad - investigate immediately)
- **Other codes:** Various response types

---

## 🎯 **Dashboard 3: SRE Shop Application**
*Application health and resource monitoring*

### 💚 **Application Availability**
**What it shows:** Overall health of all backend pods combined
- **1.0:** All pods healthy and running
- **0.5:** Half of pods are down
- **0.0:** All pods are down (critical!)

### 🔄 **Pod Restart Count**
**What it shows:** How often pods are restarting (restarts per minute)
- 🟢 **GOOD:** 0 restarts/min - Stable pods
- 🟡 **WARNING:** Occasional restarts - Monitor for patterns
- 🔴 **BAD:** Frequent restarts - Indicates instability or crashes

**Note:** High restart counts suggest application crashes, memory issues, or configuration problems

### 💚 **Pod Health Status**
**What it shows:** Timeline showing health of each individual pod
- **Green lines at 1:** Pod is healthy
- **Lines dropping to 0:** Pod crashed or became unhealthy
- **Multiple lines:** Each line represents one pod instance

---

## ⚙️ **Dashboard 4: Kubernetes Overview**
*Cluster-level infrastructure monitoring*

### 📊 **Cluster CPU Usage**
**What it shows:** Total CPU cores being used across all containers in your cluster
- **Low numbers:** Light workload on cluster
- **Higher numbers:** More containers running or heavier workload
- **Sudden spikes:** New deployments or increased activity

### 🏠 **Pod Count by Namespace**
**What it shows:** How many pods are running in each namespace
- **sre-shop:** Your application pods (backend, traffic generator)
- **monitoring:** Prometheus, Grafana, AlertManager pods
- **kube-system:** Kubernetes system pods
- **default:** Any pods without specified namespace

**Good to know:** Each namespace is like a separate room organizing different types of workloads

---

## 🎨 **Color Coding System**

### **Stat Panels (Numbers with Backgrounds)**
- 🟢 **Green Background:** Good/Healthy values
- 🟡 **Yellow Background:** Warning thresholds - monitor closely
- 🔴 **Red Background:** Critical values - take action immediately

### **Time Series Charts (Line Graphs)**
- **Green lines:** Usually good metrics
- **Red lines:** Often warning/error conditions
- **Blue lines:** Neutral information
- **Multiple colors:** Different data series

---

## 🚨 **When to Take Immediate Action**

### **Red Alert Conditions**
- ❌ Availability drops below 99%
- ❌ CPU usage above 80%
- ❌ Error budget consumption above 75%
- ❌ Any pods showing 0 (down/crashed)
- ❌ High restart rates (multiple restarts per minute)
- ❌ Memory usage above 500MB

### **Yellow Warning Conditions (Monitor Closely)**
- ⚠️ Availability between 99-99.9%
- ⚠️ CPU usage 50-80%
- ⚠️ Error budget 50-75% consumed
- ⚠️ Occasional pod restarts
- ⚠️ Memory usage 100-500MB

---

## 🔄 **How to Read Trends**

### **Healthy Patterns**
1. **Flat lines at expected values** = Good stability
2. **Gradual, predictable changes** = Normal load variations
3. **Quick recovery from spikes** = System resilience

### **Problem Patterns**
1. **Sudden drops to zero** = Outages or failures
2. **Gradual degradation** = Performance slowly getting worse
3. **Erratic spiky patterns** = Intermittent issues
4. **Sustained high values** = Overload conditions

---

## 📚 **Learning Tips**

### **Daily Health Check Routine**
1. Check **SLO Dashboard** first - overall health
2. Look at **Traffic Dashboard** - request patterns
3. Review **Application Dashboard** - pod health
4. Glance at **Kubernetes Overview** - cluster status

### **Understanding Your Normal**
- Spend time observing normal patterns
- Note typical request rates (~3/sec from traffic generator)
- Watch how metrics change during different times
- Learn what "good" looks like for your environment

### **Investigation Workflow**
1. **Problem detected** → Check SLO Dashboard for impact
2. **Drill down** → Use Traffic Dashboard to see request patterns
3. **Root cause** → Application Dashboard for pod health
4. **Infrastructure** → Kubernetes Overview for cluster issues

---

## 🎯 **Expected Normal Values**

### **For Your Traffic Generator Setup**
- **Request Rate:** ~3 requests/second
- **Availability:** 99.9-100%
- **CPU Usage:** <10% (light load)
- **Memory Usage:** <100MB
- **Pod Restarts:** 0 per minute
- **Success Rate:** 100%

### **When Values Change**
- **Higher request rate:** Normal if you scale traffic generator
- **CPU spikes:** Expected during load tests
- **Memory growth:** Monitor for leaks if continuous
- **Pod restarts:** Investigate any restarts immediately

Remember: These dashboards tell the story of your system's health - learn to read that story! 📖