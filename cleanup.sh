#!/bin/sh

rm -fr certs my-safe-directory
rm -fr cockroach
rm -fr node*

sudo nginx -s stop