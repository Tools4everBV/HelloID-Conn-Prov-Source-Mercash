# HelloID-Conn-Prov-Source-Mercash

| :warning: Warning |
|:---------------------------|
| Note that this connector is not yet implemented. Contact our support for further assistance       |

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/mercash-logo.png" width="500">
</p>

## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Prerequisites](#Prerequisites)
  + [Remarks](#Remarks)
- [Setup the connector](@Setup-The-Connector)
- [Getting help](#Getting-help)
- [HelloID Docs](#HelloID-docs)

## Introduction

_HelloID-Conn-Prov-Source-Mercash_ is a _source_ connector. Mercash provides a set of SOAP actions that allow you to programmatically interact with it's data. The HelloID connector uses the endpoints listed in the table below.

| Page Name      | Description
| ------------ | -----------
| EXT_WERK     | Employee data
| EXT_PART     | Partner data
| EXT_DVB      | Employment data
| EXT_COMP     | Components (Like: CostCenter/Function e.g.)

## Getting started



### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                        | Mandatory   |
| ------------ | -----------                        | ----------- |
| UserName     | The UserName to connect to the webservice | Yes         |
| Password     | The Password to connect to the webservice      | Yes         |
| BaseUrl      | The URL to the Mercash      | Yes         |
| ParMenu      | HelloID             | Yes         |
| ProxyAddress | Optional for using a proxy in the webrequests | No         |

### Prerequisites
 - A HelloID agent server, with access to Mercash application
 - Supported on Windows Powershell 5.1, Not supported on a Cloud agent
 - The account requires specific access in Mercash. With must be granted by the Application Manager.


### Remarks
 - The webservice return ids, which represent the property names. Instead of showing the property name itself. Therefore I create at the top of the script. Some sort of mapping that resolves the Ids to meaningful names. With might changes for different customers.
 - The connector sends the employee, partners, and employment data 1 to 1  to HelloId.
   The component details are sanitized in the connector. It selects only the latest item per component, based on the *Ingangsdatum*.

## Setup the connector

>  [Setup HelloID Source Connector](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system)

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
