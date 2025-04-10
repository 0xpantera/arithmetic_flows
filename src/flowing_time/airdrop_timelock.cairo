use starknet::ContractAddress;

#[starknet::interface]
pub trait IAirdropTimelock<TContractState> {
    fn set_reward_eligability(
        ref self: TContractState, 
        account: ContractAddress, 
        amount: felt252, 
        initial_lock_time: felt252
    );
    fn claim_reward(ref self: TContractState);
    fn increase_reward(
        ref self: TContractState, 
        seconds_to_increase_timelock: u256
    );
    fn get_reward_details(
        self: @TContractState, 
        account: ContractAddress
    ) -> (felt252, felt252);
}

#[starknet::contract]
mod AirdropTimelock {
    use core::traits::Into;
    use starknet::{
        get_caller_address, 
        ContractAddress, get_block_timestamp
    };
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::storage::Map;
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
    
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        rewards: Map<ContractAddress, felt252>, // Rewards to be distributed
        maturity_time: Map<ContractAddress, felt252>, // Maturity time for the rewards
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer("Genau", "Gen");
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl IAirdropTimelockImpl of super::IAirdropTimelock<ContractState> {
        // Set reward eligability for an account, can be set only by the owner
        // @param account: The account to set the reward eligability for
        // @param amount: The amount of tokens to set for the account
        // @param initial_lock_time: The initial lock time for the reward
        fn set_reward_eligability(
            ref self: ContractState, 
            account: ContractAddress, 
            amount: felt252, 
            initial_lock_time: felt252
        ) {
            self.ownable.assert_only_owner();
            self.rewards.write(account, amount);
            self.maturity_time.write(
                account, 
                get_block_timestamp().into() + initial_lock_time
            );
        }

        // Claim Reward for the caller, reward can be claimed only when the timelock has expired
        fn claim_reward(ref self: ContractState) {
            // Check if the caller is eligable for a reward
            let caller = get_caller_address();
            let reward = self.rewards.read(caller);
            assert(reward != 0, 'Not elligable for reward');

            // Check if the timelock has expired
            let maturity_time: u64 = self.maturity_time
                .read(caller)
                .try_into()
                .unwrap();

            assert(get_block_timestamp() >= maturity_time, 'Timelock not expired');
            // assert(self.lock_time.read(caller) < get_block_timestamp().into(), 'Timelock not expired');

            // Mint the reward to the caller, update the rewards to 0
            self.rewards.write(caller, 0);
            let to_mint: u256 = reward.into();
            self.erc20.mint(caller, to_mint);
        }

        // A user can increase the reward by increasing the timelock.
        // The maximum he can get is 2x the reward if he increases it for 1 more year
        // @param seconds_to_increase: The amount of seconds to increase the timelock by
        fn increase_reward(ref self: ContractState, seconds_to_increase_timelock: u256) {
            // Check if the caller is eligable for a reward, and the time to increase is valid
            let caller = get_caller_address();
            assert(self.rewards.read(caller) != 0, 'Not eligable for reward');
            assert(seconds_to_increase_timelock != 0, 'Invalid time to increase');

            // Calculate the reward multiplier, maximum is 2x if increased by 1 year (31536000 seconds)
            let mut reward_multiplier = 1 + (seconds_to_increase_timelock / 31536000);
            if (reward_multiplier > 2) {
                reward_multiplier = 2;
            }

            let new_reward = 
                self.rewards.read(caller) * reward_multiplier.try_into().expect('fucked multiplier');

            let new_maturity_time = 
                self.maturity_time.read(caller) + seconds_to_increase_timelock.try_into().expect('fucked new maturity');

            self.rewards.write(caller, new_reward);
            self.maturity_time.write(caller, new_maturity_time);
        }

        // Get the reward details for an account
        // @param account: The account to get the reward details for
        // @return: The reward amount and the lock time
        fn get_reward_details(self: @ContractState, account: ContractAddress) -> (felt252, felt252) {
            return (self.rewards.read(account), self.maturity_time.read(account));
        }
    }
}
