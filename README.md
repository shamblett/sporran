# Sporran - a PouchDB alike database client for Dart
[![Build Status](https://github.com/shamblett/sporran/actions/workflows/ci.yml/badge.svg)](https://github.com/shamblett/sporran/actions/workflows/ci.yml)

## Introduction

Sporran is a [PouchDB](https://pouchdb.com/) alike implementation for Dart.

It uses Lawndart(browser local storage client) and Wilt(browser CouchDB client) 
to allow browser based CouchDB users to transition between online and offline 
modes and carry on working normally.

When the browser is online Sporran acts just like Wilt, i.e is a CouchDB client, but all database
transactions are reflected into local storage. 
If the browser goes offline Sporran switches to using local storage only, when the browser comes back 
online the local database is synced up with CouchDB, all transparent to the user.

The CouchDB change notification interface is also used to keep Sporran in sync with any 3rd party
changes to your CouchDB database.

Please read the documents under the doc folder for usage information.

## Contact

Queries you can direct to me at <steve.hamblett@linux.com> or raise an issue.

