#Script for ethereum testing
#Altered to allowe custom contract input and account selection
#Created from modified script by Austin and Marlena
hashManipulation()  # Formats ipfs hash when making a new contract.
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
    ID=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' | jq -r '.result[0]')  # Grabs the first local eth account.

    curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'$ID'","'$Doolittle123'",0],"id":1}' | jq -r '.result' # Tries to unlokc account grabbed.

    curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$ID'","latest"],"id":1}' | jq -r '.result' # Gets the balance of the account. 

    TX=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'$ID'","data":"0x'$1'","gas":"0xF0000"}],"id":1}' | jq -r '.result') # Makes new contract with provided IPFS hash key.

    echo $TX
    
}

getHashKey()
{
    HASH=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"web3_sha3","params":["0x'$(echo -n "get_s()" | xxd -p -c64)'"],"id":1}' | jq -r '.result' | cut -c3-10) # 
    DATA="${HASH}"
    echo 'block number:' >&2
    curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["'$TX'"],"id":1}' | jq -r '.result.blockNumber' >&2
    R=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"'$1'","data":"0x'$DATA'"},"latest"],"id":1}' | jq -r '.result')
    DECODE=$(echo $R | sed 's/0x//' | fold -b64 | tail -1 | sed 's/00//g' | xxd -r -p)
    echo $DECODE
}

packageInstall()
{
    echo "Enter the transaction hash to pull the first part ipfs hash key from:">&2
    read TRANSACTIONHASH
    HASHONE=$(curl --data '{"method":"eth_getTransactionByHash","params":["'$TRANSACTIONHASH'"],"id":1,"jsonrpc":"2.0"}' -X POST 127.0.0.1:8545  | jq -r '.result.input')
    HASHONE=$(echo $HASHONE | xxd -r -p)
    #echo $HASH
    echo "The hash key pulled from $CONTRACT_ADDRESS is $HASHONE">&2
    echo "Is the hash key correct?(yes or no):">&2
    read CONTINUE
    
    if [ $CONTINUE = "yes" ]
    then
    echo "Enter the transaction hash to pull the second part of the ipfs hash key:"
    read TRANSACTIONHASH
    HASHTWO=$(curl --data '{"method":"eth_getTransactionByHash","params":["'$TRANSACTIONHASH'"],"id":1,"jsonrpc":"2.0"}' -X POST 127.0.0.1:8545  | jq -r '.result.input')
    HASHTWO=$(echo $HASHTWO | xxd -r -p)
    elif [ $CONTINUE = "no" ]
    then
	exit 1
    else
	echo "Invalid answer. Program will exit.">&2
	exit 1
    fi
    FULLHASHKEY=$HASHONE$HASHTWO
    echo "Your full IPFS hash key is:$FULLHASHKEY"

    echo "Would you like to install the package?:"
    read CHOICE
    if [$CHOICE == 'yes']
    then
	ipfs get $FULLHASHKEY
	echo "Now you can do a local install with a package manager."
    else
	exit 1
	
}
updateContract()
{
     echo "Input contract address you want package to be associated with.:">&2
     read CONTRACT_ADDRESS
     echo "Input IPFS hash you would like to update contract with:">&2
     read HASH
     HASHONE=${HASH:0:23}
     HASHTWO=${HASH:23}

     DATAONE=$(hashManipulation $HASHONE)
     DATATWO=$(hashManipulation $HASHTWO)
     DATAONE=${DATAONE:126:150}
     DATATWO=${DATATWO:126:150}
     echo $DATAONE>&2
     echo $DATATWO>&2
     #echo $CONTRACT_ADDRESS>&2
     ID=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' | jq -r '.result[0]')
    
     curl http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0", "method":"eth_sendTransaction", "params":[{"from": "0x27ea56211ed0044c31154efbf95ed4cd1f79110b", "to": "'$CONTRACT_ADDRESS'", "data": "0x'$DATAONE'" }], "id":1}' # Sends data to contract.
     curl http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0", "method":"eth_sendTransaction", "params":[{"from": "'$ID'", "to": "'$CONTRACT_ADDRESS'", "data": "0x'$DATATWO'" }], "id":1}'
}
searchBlockchain() # Doesnt work not sure why. Will figure out later.
{
    echo "Enter in the contract you would like to pull up ipfs hashes for:"
    read CONTRACTADDRESS
    echo "Enter in start block of contract:"
    read STARTBLOCK
    STARTBLOCK=$(echo $STARTBLOCK | xxd -pu )
    echo $STARTBLOCK >&2
    FILTER=$(curl http://127.0.0.1:8545 -X POST --data '{"method":"eth_newFilter","params":[{"fromBlock":"0x'$STARTBLOCK'","toBlock":"latest","address":"'$CONTRACTADDRESS'"}],"id":1,"jsonrpc":"2.0"}'| jq -r '.result') >> hashes.txt
    #echo $FILTER >&2
    TRANSACTIONHASHES=$(curl 127.0.0.1:8545 -X POST --data '{"method":"eth_getFilterChanges","params":["'$FILTER'"],"jsonrpc":"2.0","id":1}') >> hashes2.txt #| jq -r '.result') 
    echo $TRANSACTIONHASHES >&2
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
    DECODE=$(getHashKey $CONTRACT_ADDRESS)
    echo $DECODE
}
echo "Welcome to Get-Set Update!"
echo "======================================="
echo "Please tell us what you would like to do?"
echo "       1. Upload package to blockchain with IPFS hash."
echo "       2. Download package from the transaction hashes."
echo "       3. Update contract with new package."
echo "       4. Search the blockchain for a list of hashes."

read CHOICE

if [ $CHOICE == "1" ]
then

     echo "Compile and transaction test Ethereum"

     echo "type filename [ENTER]  "

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
     
     HASHKEY_ONE=$(main $STRINGONE)
     HASHKEY_TWO=$(main $STRINGTWO)
     FULL_HASHKEY=$HASKEY_ONE$HASHKEY_TWO
     echo "IPFS hash stored in contract: $FULL_HASHKEY"
     echo "IPFS file can be pulled using: ipfs get $FULL_HASHKEY"    
elif [ $CHOICE == "2" ]
then

    packageInstall
elif [ $CHOICE == "3" ]
then
    updateContract
elif [ $CHOICE == "4" ]
then
    searchBlockchain
else
    echo "Invalid option. Program will exit."
    exit 1
fi
