---
title: Introduction
sidebar: mydoc_sidebar
permalink: mydoc_introduction.html
folder: mydoc
---

## Overview

Welcome to MAIS documentation. 
MAIS is a time series framework for reporting data applications.

This site provides documentation, training, and other notes for MAIS framework. The instructions here are geared towards reporting teams / data teams  working on reporting. You could be a data consultant working for multiple businesses. You can use MAIS to author multiple sites for each of your projects. MAIS is built to manage data for multiple sites.

## Abstract
A time series version of a data warehouse would enable a compact, agile and utra fast data wallet to built complete reports or complement exsiting ones. Data warehouses provide a powerful solution but the main benefits are lost if additional data is required or data definitions do not match business definitions.

We propose a solution to a last mile home problem, which in the context of management reporting means additional data filtering/modifications are done on the reporting side instead of centralizing and managing them in the underlying data systems. 

A generic time series approach relies on a data model with a fixed structure. Because the data structure is generic and does not change over time this creates two major benefits for reporting applications:

1. (Single source) Time serie can be searched and combined with each other on one chart/table/dashboard with no limitations. 
2. (Agile) Data for each time serie can be processed in an independent or a batch manner. Series can be individually managed, shared, secured or audited.

MAIS enables an endless variety of source data to be processed in the compact time series format. Within MAIS this is achieved by a generic stored procedures controlled by generic parameters. The parameters use popular SQL expressions syntax shielding SQL complexity from the business users. This suport many daily scenarios and routine reporting tasks. In most of cases business work configuration changes do not require structural data changes but require changes of how transactions are aggregated controlled by the parameters. Business users can apply low risk but frequent changes themselves, while ICT staff is released for more complex and risky structural data changes or delivering new sources of data. Data sources do not require mutual data keys or details consistency. This lowers overall complexity separating the concerns between the reporting teams and ICT.  

## Getting started

To get started, see [Getting Started][index].

{% include links.html %}
