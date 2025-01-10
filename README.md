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

## Philosophy of operation

Sporran is designed to be used as a CouchDB client with a similar interface to PouchDb and the fact
that like PouchDb it allows offline as well as online usage.

There are differences however, the main one being that the CouchDB database is deemed to be the master
in all cases of conflict, in that when syncing if Couch has a different document revision to the
local one held then it is deemed to be the master and its document wins. This means any local updates that
have been made while offline will be lost. This however will only occur if you are not the only user
of your database, if you are a single user and no one else can change your database then this situation
will not occur as your local revisions will always match CouchDB.

When online all document and attachment updates are comitted to local storage as NOT_UPDATED, then
CouchDb is updated, if successful the document is now marked as UPDATED in local storage and its
revision and any new/deleted attachments are updated. If the update fails the document is left in local storage,
the document will only be removed from local storage if CouchDB replies with a conflicting
revision in which case the document will be updated from the CouchDB document and its revision updated
as necessary.

Whilst online CouchDD responds to all read and delete requests, local storage being updated as required.

When the user goes offline all document update/creation requests are performed in local storage with
the update being marked a NOT_UPDATED. Reads are from local storage and deletes operate on local storage
with the delete itself being written to a pending delete queue for processing by CouchDB when we transition
to online again. Note that whilst offline any document/attachment creations do not create a revision,
likewise updated documents retain the same revision they had last time they were online. Sporran does
not create CouchDB revisions.

When the user comes back online the sync() method is invoked(automatically or by manual call), this as you
probably suspect re-syncs local storage and CouchDB. Pending deletes are addressed first, followed by documents and
attachments marked as NOT_UPDATED. This procedure updates revision numbers and creates any new documents/
attachments as needed, also deleted attachments are addressed. The sync method operates in
conjunction with the CouchDB change notification interface which must be enabled for a full sync to be performed.
The sync operation runs in the background, the user can just carry on working, they need not wait for
the sync oeration to complete, in fact, syncing is performed transparently all the time the user is online
albeit in a more lightweight manner.

