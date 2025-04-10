# Cairo Arithmetic Vulnerabilities

This repository demonstrates two common arithmetic vulnerabilities in Cairo smart contracts related to the `felt252` data type. Cairo's `felt252` operations wrap around (similar to modular arithmetic), which can lead to serious security issues.

## Vulnerabilities Demonstrated

### 1. Balance Underflow in Simple Token

**File**: `flowing_token/flowing_token.cairo`

This vulnerability demonstrates how an attacker can exploit underflow in a token contract's balance checking:

- The contract fails to check if users have sufficient balance before transfers
- When transferring more tokens than a user has, the balance underflows (wraps around)
- This results in the attacker having a very large number of tokens (close to the maximum felt252 value)

**Attack Vector**: The attacker transfers 1 token despite having a 0 balance, causing their balance to underflow to a very large value.

### 2. Timelock Bypass in Airdrop Contract

**File**: `flowing_time/airdrop_timelock.cairo`

This vulnerability shows how an attacker can manipulate time locks through arithmetic overflow:

- The contract allows users to increase their lock time to get higher rewards
- An attacker can provide a carefully calculated value that, when added to the current lock time, causes an overflow
- This overflow results in the lock time wrapping around to a value in the past

**Attack Vector**: The attacker calls `increase_reward()` with a specific large number (`3618502788666131213697322783095070105623107215331596699973092056134130528000`) that causes the maturity time to overflow to a value before the current timestamp, allowing them to withdraw their tokens immediately.

## Security Lessons

1. **Always Check Bounds**: In Cairo, you need to manually check for overflow/underflow conditions since they don't throw errors by default.

2. **Use Integer Types**: The `felt252` type is a fundamental type that serves as the basis for creating all types in the core library. However, it is highly recommended to use the integer types instead of the `felt252` type whenever possible, as the integer types come with added security features that provide extra protection against potential vulnerabilities in the code, such as overflow and underflow checks. By using these integer types, programmers can ensure that their programs are more secure and less susceptible to attacks or other security threats.

3. **Validate State Changes**: Always verify that state changes (like timelock modifications) maintain the expected invariants of your system.

4. **Test Edge Cases**: Deliberately test with boundary values like `0`, maximum possible values, and values close to the `felt252` maximum.

## About Cairo's felt252

The `felt252` type in Cairo represents field elements in a finite field where the maximum value is `2^251 + 17 * 2^192`. Arithmetic operations on felt252 wrap around this maximum value, making overflow/underflow issues particularly dangerous in financial contracts.

## Running the Tests

The repository includes test files that demonstrate successful exploitation of these vulnerabilities:

```bash
scarb test
```

Each test shows how an attacker can manipulate the arithmetic operations to bypass security controls.
