.PHONY: build test format declare

export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount
export NONCE=$(shell starknet get_nonce --contract_address 0x063675fa1ecea10063722e61557ed7f49ed2503d6cdd74f4b31e9770b473650c --network alpha-goerli)

build:
	protostar build

format:
	protostar format src tests

install:
	protostar install

test:
	protostar test

declare:
	starknet declare --account carbonable --network=alpha-goerli --max_fee 100000000000000000 --contract ${CONTRACT_FILE} --nonce ${NONCE} --deprecated

declare-all:
	$(MAKE) declare CONTRACT_FILE=./build/CarbonableProxy.json NONCE=$(shell expr ${NONCE} + 0)
	$(MAKE) declare CONTRACT_FILE=./build/CarbonableProject.json NONCE=$(shell expr ${NONCE} + 1)
	$(MAKE) declare CONTRACT_FILE=./build/CarbonableMinter.json NONCE=$(shell expr ${NONCE} + 2)
	$(MAKE) declare CONTRACT_FILE=./build/CarbonableOffseter.json NONCE=$(shell expr ${NONCE} + 3)
	$(MAKE) declare CONTRACT_FILE=./build/CarbonableYielder.json NONCE=$(shell expr ${NONCE} + 4)
