#Script to upload ipfs hashes to the ethereum block chain.
#Created from modified script by Austin and Marlena.

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

    curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'$ID'","'$Doolittle123'",0],"id":1}' | jq -r '.result' # Tries to unlock account grabbed.

    curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["'$ID'","latest"],"id":1}' | jq -r '.result' # Gets the balance of the account. 

    TX=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'$ID'","data":"0x'$1'","gas":"0xF0000"}],"id":1}' | jq -r '.result') # Sends new contract to the Ethereum blockchain to be mined.

    echo $TX
    
}

getHashKey()  # Grabs ipfs hash key from contract.
{
    HASH=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"web3_sha3","params":["0x'$(echo -n "get_s()" | xxd -p -c64)'"],"id":1}' | jq -r '.result' | cut -c3-10) 
    DATA="${HASH}"
    echo 'block number:' >&2
    curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["'$TX'"],"id":1}' | jq -r '.result.blockNumber' >&2  # Grabs transaction properties.
    R=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"'$1'","data":"0x'$DATA'"},"latest"],"id":1}' | jq -r '.result')  # Grabs the ipfs hash key in hex form.
    DECODE=$(echo $R | sed 's/0x//' | fold -b64 | tail -1 | sed 's/00//g' | xxd -r -p) # Converts hex ipfs hash key into text.
    echo $DECODE
}
packageInstall()
{
    echo "Enter the transaction hash to pull the first part ipfs hash key from:">&2
    read TRANSACTIONHASH
    HASHONE=$(curl --data '{"method":"eth_getTransactionByHash","params":["'$TRANSACTIONHASH'"],"id":1,"jsonrpc":"2.0"}' -X POST 127.0.0.1:8545  | jq -r '.result.input') # Grabs info about the transaction including the ipfs hash key in hex form that was sent.
    HASHONE=$(echo $HASHONE | xxd -r -p)  # Converts hex ipfs hash into text.
    echo "The hash key pulled from $CONTRACT_ADDRESS is $HASHONE">&2
    echo "Is the hash key correct?(yes or no):">&2
    read CONTINUE
    
    if [ $CONTINUE = "yes" ]
    then
    echo "Enter the transaction hash to pull the second part of the ipfs hash key:"
    read TRANSACTIONHASH
    HASHTWO=$(curl --data '{"method":"eth_getTransactionByHash","params":["'$TRANSACTIONHASH'"],"id":1,"jsonrpc":"2.0"}' -X POST 127.0.0.1:8545  | jq -r '.result.input')  # Does exactly what HASHONE does. Need to do it a second time because of ipfs hash.
    HASHTWO=$(echo $HASHTWO | xxd -r -p)
    elif [ $CONTINUE = "no" ]
    then
	exit 1
    else
	echo "Invalid answer. Program will exit.">&2
	exit 1
    fi
    FULLHASHKEY=$HASHONE$HASHTWO  # Shoves part one and two of ipfs hash key together
    echo "Your full IPFS hash key is:$FULLHASHKEY"
    echo "Would you like to install the package?:"
    read CHOICE
    if [$CHOICE == 'yes']
    then
	ipfs get $FULLHASHKEY  # Download package into current directory from ipfs.
	echo "Now you can do a local install with a package manager."
    else
	exit 1
    fi
}
updateContract()
{
     echo "Input contract address you want package to be associated with.:">&2
     read CONTRACT_ADDRESS
     echo "Input IPFS hash you would like to update contract with:">&2
     read HASH
     HASHONE=${HASH:0:23}  # Chops ipfs hash in half.
     HASHTWO=${HASH:23}
     DATAONE=$(hashManipulation $HASHONE) # Converts ipfs hash into hex form with correct formatting to be sent.
     DATATWO=$(hashManipulation $HASHTWO)
     DATAONE=${DATAONE:126:150}  # Gets rid of 0's in hex form of ipfs hash. Ether didn't like them.
     DATATWO=${DATATWO:126:150}
     echo $DATAONE>&2
     echo $DATATWO>&2
     #echo $CONTRACT_ADDRESS>&2
     ID=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' | jq -r '.result[0]') # Grabs local ethereum wallet address. 
    
     curl http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0", "method":"eth_sendTransaction", "params":[{"from": "'$ID'", "to": "'$CONTRACT_ADDRESS'", "data": "0x'$DATAONE'" }], "id":1}' # Sends part one of the ipfs hash to contract.
     curl http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0", "method":"eth_sendTransaction", "params":[{"from": "'$ID'", "to": "'$CONTRACT_ADDRESS'", "data": "0x'$DATATWO'" }], "id":1}' # Sends part two of the ipfs hash to contract.
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
updatePackages()
{
    echo "Need to think about what to do. Will make later."
}

main()
{
    DATA=$(hashManipulation $1)
    CONTRACT_BINHEX=${CONTRACT_BINHEX}${DATA}  # Shoves created contract and ipfs hash in converted hex form together. This is done when a new contract is being created.
    echo "=========================================">&2
    TX=$(sendTransaction $CONTRACT_BINHEX)  # Gives newly created contract to method so, it can be uploaded to blockchain.
    echo "Transaction ID: $TX" >&2
    echo "=========================================">&2
    TX=${TX:24} # The TX constant had 3 different strings of text inside it. We only needed the transaction hash so, we cut out the other two strings.
    while :
    do
	CONTRACT_ADDRESS=$(curl -sL http://127.0.0.1:8545 -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["'$TX'"],"id":1}' | jq -r '.result.contractAddress')  # Grabs contract address from the transaction hash used to create the contract.
	if echo $CONTRACT_ADDRESS | grep '0x' >/dev/null 2>&1
	then
	    break
	fi
    done
    echo "==========================================">&2
    echo "contract address: $CONTRACT_ADDRESS" >&2
    DECODE=$(getHashKey $CONTRACT_ADDRESS) # Sends the contract address to the method that will grab it.
    echo $DECODE
}

echo "       MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMMMMMXkx0WMMMMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMMMWKd;';kWMMMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMMW0dl;..,xNMMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMNOdol;...'oXMMMMMMMMMMMMMM
       MMMMMMMMMMMMMNkolol;.....lKMMMMMMMMMMMMM
       MMMMMMMMMMMMXkollll;......:0WMMMMMMMMMMM
       MMMMMMMMMMWKxolllll;.......;kWMMMMMMMMMM
       MMMMMMMMMW0dlllllll;........,xNMMMMMMMMM
       MMMMMMMMNOdllllllll;.........'oXMMMMMMMM
       MMMMMMMNkolllllllll;...........lKWMMMMMM
       MMMMMMXxolllllllllc,............:0WMMMMM
       MMMMWKxollllllcc:,'.. ...........;kWMMMM
       MMMW0dolllc:;,'.....       .......,xNMMM
       MMNOolc:;,'.........           ....'oXMM
       MNx:,'..............               ..cXM
       MNOo:'..............              .'ckNM
       MWWWN0dc,...........           .;oOXWNWM
       MWX00XWWKkl;'.......       ..:d0NNKkx0WM
       MMMXkdk0XWWXOd:'....    .,lkXWN0d:,c0WMM
       MMMMN0dooxOKNWN0xc,...;oONWXko;..'dXMMMM
       MMMMMWKxollodk0XWWKOOKNN0xc,....:OWMMMMM
       MMMMMMMNOdllllodxOKXKOo:'.....'lKMMMMMMM
       MMMMMMMMWKxollllloo:,'.......;kNMMMMMMMM
       MMMMMMMMMMXkollllll;........c0WMMMMMMMMM
       MMMMMMMMMMMW0dlllll;......,dNMMMMMMMMMMM
       MMMMMMMMMMMMWXxolll;.....:OWMMMMMMMMMMMM
       MMMMMMMMMMMMMMNOdll;...'oXMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMMWKxl;..;kNMMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMMMMNkc;lKWMMMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMMMMMWXXNMMMMMMMMMMMMMMMMMM
       MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
echo "======================================================="
echo "@           Welcome to Get-Set Update!                @"
echo "======================================================="
echo "Please tell us what you would like to do?"
echo "   1. Upload package to blockchain with IPFS hash."
echo "   2. Download package from the transaction hashes."
echo "   3. Update contract with new package."
echo "   4. Search the blockchain for a list of hashes."
echo "   5. Update installed packages."
echo "======================================================="               
read CHOICE
if [ $CHOICE == "1" ]
then
     echo "Compile and transaction test Ethereum"
     echo "type filename [ENTER]  "
     read fileInput
     CONTRACT_BINHEX=$(solc --optimize --combined-json bin echo.sol | jq -r '.contracts."'$fileInput':echo".bin')  # Compiles the smart contract.
     echo "........" 
     echo $CONTRACT_BINHEX  
     echo "Input IPFS file hash:"
     read STRING 
     STRINGONE=${STRING:0:23}  # Chops ipfs hash in half so, it can be sent.
     STRINGTWO=${STRING:23}
     echo "STRINGONE: $STRINGONE"
     echo "STRINGTWO: $STRINGTWO"
     
     HASHKEY_ONE=$(main $STRINGONE) # Gets ipfs hashkey again.
     HASHKEY_TWO=$(main $STRINGTWO) # ^
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
