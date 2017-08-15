#Script for ethereum testing
#Altered to allowe custom contract input and account selection
#Created from modified script by Austin and Marlena
hashManipulation()
{
 STRING_LEN=$(printf "%064x\n" ${#1})
 STRING_HEX=$(echo -n $1 | xxd -p -c 32)
 STRING_FILL=$(( 64 - ${#STRING_HEX} ))
 STRING_DATA=$(echo -n $STRING_HEX ; eval printf '0%.0s' {1..$STRING_FILL})
 OFFSET=$(printf "%064x\n" 32)
 DATA="${OFFSET}${STRING_LEN}${STRING_DATA}"
 echo $DATA
}


sendTransaction()
{
ID=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' | jq -r '.result[0]')

curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'$ID'","'$Doolittle123'",0],"id":1}' | jq -r '.result'

curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$ID'","latest"],"id":1}' | jq -r '.result'

TX=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'$ID'","data":"0x'$1'","gas":"0xF0000"}],"id":1}' | jq -r '.result')

echo $TX
}

decode()
{
HASH=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"web3_sha3","params":["0x'$(echo -n "get_s()" | xxd -p -c64)'"],"id":1}' | jq -r '.result' | cut -c3-10)
DATA="${HASH}"
echo 'block number:' >&2
curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["'$TX'"],"id":1}' | jq -r '.result.blockNumber' >&2
R=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"'$1'","data":"0x'$DATA'"},"latest"],"id":1}' | jq -r '.result')
DECODE=$(echo $R | sed 's/0x//' | fold -b64 | tail -1 | sed 's/00//g' | xxd -r -p)
echo $DECODE
}

main()
{
DATA=$(hashManipulation $1)
CONTRACT_BINHEX=${CONTRACT_BINHEX}${DATA}
#echo $DATA | fold -w64
echo "=========================================">&2
TX=$(sendTransaction $CONTRACT_BINHEX)
echo "Transaction ID: $TX" >&2
echo "=========================================">&2
TX=${TX:24}
while :
do
    CONTRACT_ADDRESS=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["'$TX'"],"id":1}' | jq -r '.result.contractAddress')
    if echo $CONTRACT_ADDRESS | grep '0x' >/dev/null 2>&1
    then
	break
    fi
done
echo "==========================================">&2
echo "contract address: $CONTRACT_ADDRESS" >&2
DECODE=$(decode $CONTRACT_ADDRESS)
echo $DECODE
}


echo "Compile and transaction test Ethereum"

echo "type filename [ENTER]:"

read fileInput

CONTRACT_BINHEX=$(solc --optimize --combined-json bin echo.sol | jq -r '.contracts."'$fileInput':echo".bin')

echo "........" 
echo $CONTRACT_BINHEX  

echo "Input IPFS file hash:"
read STRING 
STRINGONE=${STRING:0:23}
STRINGTWO=${STRING:23}
echo "STRINGONE: $STRINGONE"
echo "STRINGTWO: $STRINGTWO"

DECODEONE=$(main $STRINGONE)
DECODETWO=$(main $STRINGTWO)
FULLDECODE=$DECODEONE$DECODETWO
echo "IPFS hash stored in contract: $FULLDECODE"
echo "IPFS file can be pulled using: ipfs get filehash"
