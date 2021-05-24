#!/bin/bash

source scripts/utils.sh

CC_NAME=cc1
CC_SRC_PATH=/opt/gopath/src/github.com/chaincode1/
CC_RUNTIME_LANGUAGE=golang
CC_VERSION=1
CC_SEQUENCE=1

ORDERER_CA=/var/crypto/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem
CHANNEL_NAME=channel1
INIT_REQUIRED="--init-required"
ORG=1

verifyResult() {
  if [ $1 -ne 0 ]; then
      fatalln "$2"
  fi
}

packageChaincode() {
  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode packaging has failed"
  successln "Chaincode is packaged"
}

installChaincode() {
  set -x
  peer lifecycle chaincode install ${CC_NAME}.tar.gz >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode installation on peer0.org${ORG} has failed"
  successln "Chaincode is installed on peer0.org${ORG}"
}

queryInstalled() {
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
  verifyResult $res "Query installed on peer0.org${ORG} has failed"
  successln "Query installed successful on peer0.org${ORG} on channel"
}

approveForMyOrg() {
  set -x
  peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --tls --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME'"
}

commitChaincodeDefinition() {
  PEER_CONN_PARMS="--peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /var/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
  set -x
  peer lifecycle chaincode commit -o orderer.example.com:7050 --tls --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} $PEER_CONN_PARMS --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition committed on channel '$CHANNEL_NAME'"
}

queryCommitted() {
  set -x
  peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

chaincodeInvokeInit() {
  set -x
  peer chaincode invoke -o orderer.example.com:7050 --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CC_NAME} $PEER_CONN_PARMS --isInit -c '{"Args":["Init","a","100","b","100"]}' >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

chaincodeQuery() {
  set -x
  peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c '{"Args":["query","a"]}' >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

packageChaincode

installChaincode

queryInstalled

approveForMyOrg

commitChaincodeDefinition

queryCommitted

chaincodeInvokeInit

echo "Sleeping for 10 seconds.."
sleep 10

chaincodeQuery
