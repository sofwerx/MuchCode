//*************************************
//Simple Eth Contract that gets and
//sets a string. 
//Purpose: For Testing Eth Scripts
//*************************************

pragma solidity ^0.4.9;

contract echo {

    //Global String
    string s;
    string message ="The ipfs hash has been store onto the blockchain";
    event hashStored(string, uint);
    //Constructor function
    //Only called once - when deployed by the owner
    function echo(string initial) {
    	s = initial;
    }
    
    //String Setter
    function set_s(string input) {
    	s = input;
    	hashStored(message, 1);
    }
    
    //String Getter
    function get_s() returns (string) {
    	return s;
    }
}
