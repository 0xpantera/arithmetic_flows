use starknet::ContractAddress;

// The ISimpleToken interface
#[starknet::interface]
pub trait ISimpleToken<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: felt252);
    fn transfer(ref self: TContractState, to: ContractAddress, amount: felt252);
    fn balance_of(self: @TContractState, account: ContractAddress) -> felt252;
}

// The SimpleToken contract
#[starknet::contract]
mod SimpleToken {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::Map;
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, felt252>,
        minter: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, minter: ContractAddress) {
        self.minter.write(minter);
    }

    // Public Functions
    #[abi(embed_v0)]
    impl ISimpleTokenImpl of super::ISimpleToken<ContractState> {
        // Only the minter can mint new tokens
        // @param to: The account to mint the tokens to
        // @param amount: The amount of tokens to mint
        fn mint(ref self: ContractState, to: ContractAddress, amount: felt252) {
            assert(get_caller_address() == self.minter.read(), 'Only minter');
            let balance = self.balances.read(to);
            self.balances.write(to, balance + amount)
        }

        // Transfer tokens from the caller to another account
        // @param to: The account to transfer the tokens to
        // @param amount: The amount of tokens to transfer
        fn transfer(ref self: ContractState, to: ContractAddress, amount: felt252) {
            let caller = get_caller_address();
            self.balances.write(caller, self.balance_of(caller) - amount);
            self.balances.write(to, self.balance_of(to) + amount);
        }

        // Get the balance of an account
        // @param account: The account to get the balance of
        fn balance_of(self: @ContractState, account: ContractAddress) -> felt252 {
            self.balances.read(account)
        }
    }
}
