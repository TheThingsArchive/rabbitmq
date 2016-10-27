#!/bin/bash

cfssl genkey -initca ca.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=cert-config.json server.json | cfssljson -bare server
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=cert-config.json client.json | cfssljson -bare client
