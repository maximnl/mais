Welcome to MAIS documentation. 

MAIS is an open source SQL framework for self service ETL integrated with a time series data storage which is optimized for corportate reporting data needs.  

# Motivation

Business operations management relies on periodic reports/dashboards for performance management, evaluations, meetings/decision support purposes. Such high aggregation level reports pull data from a centralized datawarehouse(s). 

?>Data warehouses provide a powerful centralized solution for data reporting, but the main benefits are lost if additional data or transformations are required.  

**Periodic reports/dashboards context** as opposed to detailed/ad hoc analytical reports, differs in a number of ways: 
- involves business data such as targets/budget/forecast, 
- enriches and combines factual information with various ratios, YTD calculations,
- requires legacy, a continious long history of data, versioning of data, 
- involves integration of keyless data , custom raw files. 

Fully centralized approaches may overshoot the target by trying to integrate different business domains defintions which may contradict each other and differ from the data context. This may lead to various bottlenecks such as additional data modeling needs, IT infrustructure occupancy, ICT staff availability, waiting time and costs. A faster and a more decentralized alternative could be pulling some data directly from data hubs or independent data sources. However, such bold decentralized shortcuts become disrupted on a longer run by source data changes, staff rotations, many copies of the same logica and data filters. While the probability of the disruptions may seem low, the consequences may influence a large amount of reporting users, violate legal requirements, or require a complete rebuild and thus carry significant continuity and data quality risks.   

# Use cases

MAIS is a practical data decentralization strategy to reduce the overal complexity and dependency of corporate reporting on a single team/platform or tool. It is a game changer for the boundaries of many teams:
* A reporting team centralizes and manages metadata for series names, metadata and data aggregations. The last ones are ETL configurations which influcence time series ETL directly. 
* ICT data team enables centralized and **continious** and self service integration of less structured (user) data or data with challenging integration requirements. 
* The business operations gain an audited, versioned, fast and user friendly access to all reporting data. 
* Business analysts gain a fast access to a light historical data storage from PowerBI, Excel or any reporting tool without data modeling 
* Forecasters instantly share forecasts and actuals they are based on 
* Buscritical reporting items with forecasts, many years of actuals history  

# Foreword 

A data strategy for the management reports seems to be a straightforward path: we develop a data warehouse and we use it to feed data. In practice however, this turn out to be a more complex process on a long run: change management, data consistency, changing business requirements can increasingly consume a great portion of your staff. 

?>While we would never attempt to design a car that serves both a transport company and a celebrity, yet we chaise data for corporate reporting with a single strategy. 

Treating all reports in a similar way is an attractive solution. Nevertheless, it is easy to observe that:

?>A) Some reports are used for daily meetings and have a high load while other ad hoc reports can be used once a year or one time. 
B) Some reports carry data from a single operational source while other reports such as monthly closure reports, span many operational systems and require to bring diverse information together for critical business decisions. Management reports tend to combine in one table/chart time aggregated data from different sources such as work itemes, FTEs, forecasts, indicators, last year actuals and all kind of ratios. For such tight integration it is essential that **all** data per a report part to be pulled from the same **a single** data source. In many analitical scenarios it is beneficial to have all reports items to be individually accesible as data in order to share them, apply calculations, combine, audit and optimize reads. 

The major motivation for starting MAIS open source project was an implementation of a forecasting approach to corporate reporting. By gathering user feedback from forecasters and business users we assessed its practical business values in a broader reporting context. Instead of bringing the actual data to the forecast suitable format (time series) and then back to reports, we attempted to reproduce all management information using time series. This required an automation as data for hundreds of time series had to be managed, which is essentially what MAIS does for you.

## History

During 7 years of continuous development and evaluation, we found MAIS approach brings other than forecasting needs practical values: 

* we observed less incidents, a better adoption of reports by management and more trust in the information, 
* our definitions were also the data processing rules, which were easy to find and change,
* we could easily switch from one source to another when operational systems were replaced without braking time series and keeping long history,
* we could integrate sources that were not in the data warehouse such as data keyless sources, reporting output from other systems, forecasting data, 
* we could collaborate in a more agile manner, follow different business configuration changes,  
* we could increase frequencies of data updates and diversify data flows. When it was necessary, time series data could easily be exchanged via Azure SQL database and consumed by PowerBI or Excel directly and at a high performance,
* Eventually we migrated MAIS based and rather complex reporting environment from SSAS/EXCEL rails to PowerBI and Azure SQL database in less than 2 month. 

Before MAIS, essential business information was not available out of the box but required filtering. The data context of products/workflows transactions did not match well the operational context - how the work was planned and executed. Reporting software required data to be from the same source in order to be presented on one chart/table. We could not easily match what we wanted with the reporting functionalities despite excessive knowledge. When filtering was done in one report, it had to be repeated in another. When calculations over one measure were developed, the same calculations had to be repeated over another measure. While making a single source report was not an issue, combining and keeping consistent reporting elements across multiple reports was challenging. Much time was spend on analysing and finding the differences. There seemed to be a better way.  

MAIS would not be possible without a great collaboration with the business and ICT. A unique situation of developing at the business for the business gave incredible insights. We are thankful to all business users involved for their patience, feedback and positive energy. We think many reporting teams may benefit from our experience and a generic, scalable approach. MAIS makes the life of planners, forecasters, reporting teams members and operational managers so much easier. We will continue spending a great portion of efforts on further development and support of new MAIS community members. New modules, useful data and fixes will serve all the members, making them more successful and making their reports more rich, analytical, beautiful.    

We could jump to a technical details of MAIS, but we would like to spend everyone's time by giving a business introduction on a reporting situation which we think benefits the most. In case it makes sense to you, please consider following our project, installing MAIS and contacting us for any questions or support. After all, the proof of pudding is in the eating.


[Maxim Ivashkov](https://www.linkedin.com/in/ivashkov/?locale=nl_NL) - developer and founder of MAIS.
![image](https://user-images.githubusercontent.com/33482502/189649207-d2c9d480-8611-4524-8736-9295edda1b0c.png)


# Planning and forecasting

Operational businesses/departments such as contact centers, logistical centers or mass-project organizations, - are demand driven. Their operational strategy aims to keep a good match between the resources and changing work demand at all times. Staff scheduling, daily traffic management, seasonal events, vacations, new services, staff exchange among teams, new ways of work - all require a flexible work breakdown structure and a multi channel strategy. Work breakdown structures became multi skilled and organized in matrix. Workflows may involve different teams or even business units. All of this makes a tactical planning a challenging task as work is planned in one system and work is done in many others. 

A proper resource management strategy includes resource planning and forecasting. It can save a significant portion of operational costs next to other benefits. A well balanced staff/work ratio contributes to a less stressful environment, beter daily business decisions, more efficient meetings, higher NPS scores, self marketing due to better accessibility and planning precision. A better planning process enables higher workflow quality and increases profitability. 

Capacity planning and workforce management (WFM) is data driven and highly dependent on both - the quality of operational data and the ability to plan the future work demand. Data availability largely depends on planning and reporting teams which often combine these tasks. These teams support business operations and all other business units playing an important role in capacity management. 

On one hand, as a member of a planning and reporting team you may have noticed that: 

?> combined data from ***ALL*** management reports is just a tiny portion (<1%) of a corporate data warehouse data. 

This disproportion happens because the management data is A) limited to few selected indicators which management is capable of to follow over time, B) data is time aggregated (seazon, month, week, day) and C) transaction details are left out. 

On the other hand, reports are far from just plug and play the warehouse data. Corporate reports require private analytical/aggregation software, custom calculations, filtering, adjustments and often manual copy paste/file management steps. Partially this happens because operational data is mostly product/transaction driven. Transactions carry data details which may or may not match the business definitions and/or the breakdown structure of resources required to produce those transactions. 

Reporting teams are pushed to compensate all shortcoming of data within the reports. They spend efforts to select, filter, modify, aggregate and visualise data. Their results do become "locked" at the report level or report model levels. Reporting software often features proprietary syntax/data technology which mixes data, representation and proprietary syntax. This makes ease of central definitions, calculations, scaling, logic and data consistency challenging. By partially shifting critical business knowledge to the reporting side, the businesses limit abilities to:

* centralize definitions, make changes quick and consistent
* centralize custom row data sources such as forecasts
* freeze and audit data
* work with different data hierarchies 
* easily switch/combine reporting solutions, 
* benefit from cloud technologies, 
* apply analytics at scale,
* store, share and reuse reporting data, 
* mitigate risks of staff departure or four eyes principles.

Reporting teams are concerned with a fast growing amount and variety of data, while the single version of truth principle must hold across many departments at all times - finance, operations, sales, marketing. Important business decisions require different reports to be combined together. Definitions changes, data structure changes, third party software changes, business configuration changes turn data consistency into a challenging task. The data processing cycles (ETL) partially addresses these concerns. Nevertheless, corporate data warehouses focus primarily on data details as they are designed to store as much business related data as possible for any potential ad hoc analysis. Such solutions carry large volumes and complex interdependencies, thereof requiring highly skilled ICT staff. This bias of reporting data on ICT side limits business participation and requires reporting teams go though complex ad hoc process on the reporting side , again and again and again.  

For some organisations it can be beneficial to have an extra reporting strategy and separate reporting data concerns from the data warehouse concerns. Consider that your major management/corporate reports may pull data not from a warehouse directly but from a second layer data solution. As reports carry low volume of data by itself, it should be possible to develop such a solution at a very light weight, consisting of only distilled and ready to plug and play data. At least in theory. Such reporting data wallet can be made less dependent on the operational data definitions and be driven by business/planning/capacity management definitions, enabling the plug and play principle. As most of the transaction details can be left out, the data can be managed in a more agile manner, be processed and shared at better speed/frequency, contributing to sharing, performance, cloud usage and eventually saving the energy. 

In fact, such an example of practical separation of reporting data from operational data is well known to the accountants. By consolidating financial transactions into a system of accounts, an operational data becomes well defined/named, compact, consistent. Would you consider to ask an accountant to compile a quarterly financial report not from a financial system but from a data warehouse directly? Well, good luck with that! If a proper operations management can save at least just as much money as proper financial management, can operations benefit from following, at least partially, the accounting principles and reporting standards? Are not we matching work/staff similar to debit/credit? For some, it can be an opening for powerful reporting strategy changes and for some it may not be applicable, but if all the above speaks to you and makes at least some sense, please prepare to dive into more technical details. 

# History

MAIS means CORN in dutch. A series structure of corns is iconic for the way we suggest to model business information, using 100% generic [time series]. 

2004 - The early bricks of MAIS can be traced to 2004 as a spinoff of PhD design research at the technical university of Eindhoven [TU/e]. 
2008 - Development of Variant as a follow up on intensive business intelligence practice at various contact centers in the Netherlands: BookingCom, Achmea, ING. Variant is a forecasting application for the contact centers. 
2014 - MAIS was started in 2014 on SQL server platform as a remake of Variant. This milestone added a time series engine based on SQL. The engine was inspired by SAS base macros, developed during 2004-2008 BI consulting time. 
2020 - MAISED is implemented on SQL Azure as a multi tenant PHP web application on top of MAIS.  
2021 - First migration of a reporting environment from SSAS/Excel rails on PowerBI. Many improvements and bug fixes during this period. Nearly complete code rewrite. 
2022 - Added support of Production/Acceptation environments, data synchronization, several analytical stored procedures.  

# Community
In our community we welcome reporting specialists, workforce managers, planners involved in support of business operations. MAIS code is fully SQL server compliant, we constantly extend the framework with new functionalities and public data. This gives an edge to our members for better results, growing income and client satisfaction. Our community helps to find consulting opportunities, learn skills and meet great people.  



