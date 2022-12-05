// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn, assert_le, split_felt, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_lt,
    uint256_eq,
    uint256_unsigned_div_rem,
    uint256_mul_div_mod,
)
from starkware.starknet.common.syscalls import (
    get_block_timestamp,
    get_caller_address,
    get_contract_address,
)

// Project dependencies
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc721.IERC721 import IERC721
from openzeppelin.token.erc721.enumerable.IERC721Enumerable import IERC721Enumerable
from openzeppelin.security.reentrancyguard.library import ReentrancyGuard

// Local dependencies
from src.interfaces.project import ICarbonableProject

//
// Events
//

@event
func Claim(address: felt, quantity: felt, time: felt) {
}

@storage_var
func carbonable_project_address_() -> (address: felt) {
}

@storage_var
func registered_owner_(tokenId: Uint256) -> (address: felt) {
}

@storage_var
func registered_time_(tokenId: Uint256) -> (time: felt) {
}

@storage_var
func times_len_() -> (length: felt) {
}

@storage_var
func times_(index: felt) -> (absorption: felt) {
}

@storage_var
func absorptions_len_() -> (length: felt) {
}

@storage_var
func absorptions_(index: felt) -> (absorption: felt) {
}

@storage_var
func claimable_(address: felt) -> (absorption: felt) {
}

@storage_var
func claimed_(address: felt) -> (absorption: felt) {
}

@storage_var
func users_len_() -> (length: felt) {
}

@storage_var
func users_(index: felt) -> (address: felt) {
}

@storage_var
func known_user_(address: felt) -> (bool: felt) {
}

namespace CarbonableOffseter {
    //
    // Constructor
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        carbonable_project_address: felt,
        times_len: felt,
        times: felt*,
        absorptions_len: felt,
        absorptions: felt*,
    ) {
        alloc_locals;
        carbonable_project_address_.write(carbonable_project_address);

        // [Check] Array consistency
        with_attr error_message(
                "CarbonableOffseter: times and absorptions must have the same len") {
            assert times_len = absorptions_len;
        }

        _write_times(times_len=times_len, times=times);
        _write_absorptions(absorptions_len=absorptions_len, absorptions=absorptions);

        return ();
    }

    //
    // Getters
    //

    func carbonable_project_address{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() -> (carbonable_project_address: felt) {
        let (carbonable_project_address) = carbonable_project_address_.read();
        return (carbonable_project_address,);
    }

    func times{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        times_len: felt, times: felt*
    ) {
        let (times_len, times) = _read_times();
        return (times_len=times_len, times=times,);
    }

    func absorptions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        absorptions_len: felt, absorptions: felt*
    ) {
        let (absorptions_len, absorptions) = _read_absorptions();
        return (absorptions_len=absorptions_len, absorptions=absorptions,);
    }

    func total_deposited{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        balance: Uint256
    ) {
        let (contract_address) = get_contract_address();
        let (carbonable_project_address) = carbonable_project_address_.read();

        let (balance) = IERC721.balanceOf(
            contract_address=carbonable_project_address, owner=contract_address
        );

        return (balance=balance,);
    }

    func total_claimed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        total_claimed: felt
    ) {
        let (users_len, users) = _read_users();

        if (users_len == 0) {
            return (total_claimed=0,);
        }

        let (total_claimed) = _total_claimed_iter(index=users_len - 1, users=users);
        return (total_claimed=total_claimed,);
    }

    func total_claimable{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        total_claimable: felt
    ) {
        let (users_len, users) = _read_users();

        if (users_len == 0) {
            return (total_claimable=0,);
        }

        let (total_claimable) = _total_claimable_iter(index=users_len - 1, users=users);
        return (total_claimable=total_claimable,);
    }

    func total_absorption{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        absorption: felt
    ) {
        let (current_time) = get_block_timestamp();
        let (absorption) = _compute_absorption(time=current_time);
        return (absorption=absorption,);
    }

    func claimable_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        address: felt
    ) -> (claimable: felt) {
        alloc_locals;

        let (current_time) = get_block_timestamp();
        let (computed_claimable) = _claimable(address=address, time=current_time);
        let (stored_claimable) = claimable_.read(address);
        let (stored_claimed) = claimed_.read(address);
        return (claimable=stored_claimable + computed_claimable - stored_claimed,);
    }

    func claimed_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        address: felt
    ) -> (claimed: felt) {
        let (claimed) = claimed_.read(address);
        return (claimed=claimed,);
    }

    func registered_owner_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (address: felt) {
        // [Check] Uint256 compliance
        with_attr error_message("CarbonableOffseter: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        // [Check] Owned token id
        let (contract_address) = get_contract_address();
        let (carbonable_project_address) = carbonable_project_address_.read();
        // [Check] Throws error if unknown token id
        let (owner) = IERC721.ownerOf(
            contract_address=carbonable_project_address, tokenId=token_id
        );
        with_attr error_message("CarbonableOffseter: token_id has not been registered") {
            assert owner = contract_address;
        }

        let (address) = registered_owner_.read(token_id);
        return (address=address,);
    }

    func registered_time_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (time: felt) {
        // [Check] Uint256 compliance
        with_attr error_message("CarbonableOffseter: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }
        // [Check] Owned token id
        let (contract_address) = get_contract_address();
        let (carbonable_project_address) = carbonable_project_address_.read();
        // [Check] Throws error if unknown token id
        let (owner) = IERC721.ownerOf(
            contract_address=carbonable_project_address, tokenId=token_id
        );
        with_attr error_message("CarbonableOffseter: token_id has not been registered") {
            assert owner = contract_address;
        }

        let (time) = registered_time_.read(token_id);
        return (time=time,);
    }

    //
    // Externals
    //

    func claim{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        success: felt
    ) {
        alloc_locals;

        // [Check] Total offsetable not null
        let (caller) = get_caller_address();
        let (claimable) = claimable_of(caller);
        let not_zero = is_not_zero(claimable);
        with_attr error_message("CarbonableOffseter: claimable balance must be positive") {
            assert not_zero = TRUE;
        }

        // [Effect] Transfer value from claimable to claimed
        let (stored_claimed) = claimed_.read(caller);
        let claimed = stored_claimed + claimable;
        claimed_.write(caller, claimed);

        let (current_time) = get_block_timestamp();
        Claim.emit(address=caller, quantity=claimable, time=current_time);
        return (success=TRUE,);
    }

    func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (success: felt) {
        alloc_locals;

        // [Security] Start reetrancy guard
        ReentrancyGuard.start();

        // [Check] Uint256 compliance
        with_attr error_message("CarbonableOffseter: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }

        // [Interaction] Transfer token_id from caller to contract
        let (carbonable_project_address) = carbonable_project_address_.read();
        let (caller) = get_caller_address();
        let (contract_address) = get_contract_address();
        IERC721.transferFrom(
            contract_address=carbonable_project_address,
            from_=caller,
            to=contract_address,
            tokenId=token_id,
        );

        // [Check] Transfer successful
        let (owner) = IERC721.ownerOf(
            contract_address=carbonable_project_address, tokenId=token_id
        );
        with_attr error_message("CarbonableOffseter: transfer failed") {
            assert owner = contract_address;
        }

        // [Effect] Register the caller with the token id and the current timestamp
        let (current_time) = get_block_timestamp();
        registered_owner_.write(token_id, caller);
        registered_time_.write(token_id, current_time);

        // [Security] End reetrancy guard
        ReentrancyGuard.end();

        // [Effect] Register the caller
        let (is_known) = known_user_.read(caller);
        let (index) = users_len_.read();
        if (is_known == FALSE) {
            users_.write(index, caller);
            users_len_.write(index + 1);
            known_user_.write(caller, TRUE);
            return (success=TRUE,);
        }
        return (success=TRUE,);
    }

    func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (success: felt) {
        alloc_locals;

        // [Security] Start reetrancy guard
        ReentrancyGuard.start();

        // [Check] Uint256 compliance
        with_attr error_message("CarbonableOffseter: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }

        // [Effect] Remove the caller from registration for the token id
        registered_owner_.write(token_id, 0);
        registered_time_.write(token_id, 0);

        // [Effect] Store cumulated claimable
        let (caller) = get_caller_address();
        let (claimable) = claimable_of(caller);
        let (stored_claimable) = claimable_.read(caller);
        claimable_.write(caller, stored_claimable + claimable);

        // [Interaction] Transfer token_id from contract to call
        let (carbonable_project_address) = carbonable_project_address_.read();
        let (contract_address) = get_contract_address();
        IERC721.transferFrom(
            contract_address=carbonable_project_address,
            from_=contract_address,
            to=caller,
            tokenId=token_id,
        );

        // [Check] Transfer successful
        let (owner) = IERC721.ownerOf(
            contract_address=carbonable_project_address, tokenId=token_id
        );
        with_attr error_message("CarbonableOffseter: transfer failed") {
            assert owner = caller;
        }

        // [Security] End reetrancy guard
        ReentrancyGuard.end();

        return (success=TRUE,);
    }

    //
    // Internals
    //

    func _write_times{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        times_len: felt, times: felt*
    ) {
        alloc_locals;

        let not_zero = is_not_zero(times_len);
        with_attr error_message("CarbonableOffseter: times_len must be positive") {
            assert not_zero = TRUE;
        }
        times_len_.write(times_len);
        _write_times_iter(index=times_len - 1, times=times);
        return ();
    }

    func _write_times_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, times: felt*
    ) {
        alloc_locals;
        times_.write(index, times[index]);
        if (index == 0) {
            return ();
        }
        _write_times_iter(index=index - 1, times=times);
        return ();
    }

    func _read_times{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        times_len: felt, times: felt*
    ) {
        alloc_locals;
        let (times_len) = times_len_.read();
        let (local times: felt*) = alloc();
        _read_times_iter(index=times_len - 1, times=times);
        return (times_len=times_len, times=times);
    }

    func _read_times_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, times: felt*
    ) {
        alloc_locals;
        let (time) = times_.read(index);
        assert times[index] = time;
        if (index == 0) {
            return ();
        }
        _read_times_iter(index=index - 1, times=times);
        return ();
    }

    func _write_absorptions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        absorptions_len: felt, absorptions: felt*
    ) {
        alloc_locals;

        let not_zero = is_not_zero(absorptions_len);
        with_attr error_message("CarbonableOffseter: absorptions_len must be positive") {
            assert FALSE = 1 - not_zero;
        }
        absorptions_len_.write(absorptions_len);
        _write_absorptions_iter(index=absorptions_len - 1, absorptions=absorptions);
        return ();
    }

    func _write_absorptions_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, absorptions: felt*
    ) {
        alloc_locals;
        absorptions_.write(index, absorptions[index]);
        if (index == 0) {
            return ();
        }
        _write_absorptions_iter(index=index - 1, absorptions=absorptions);
        return ();
    }

    func _read_absorptions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        absorptions_len: felt, absorptions: felt*
    ) {
        alloc_locals;
        let (absorptions_len) = absorptions_len_.read();
        let (local absorptions: felt*) = alloc();
        _read_absorptions_iter(index=absorptions_len - 1, absorptions=absorptions);
        return (absorptions_len=absorptions_len, absorptions=absorptions);
    }

    func _read_absorptions_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, absorptions: felt*
    ) {
        alloc_locals;
        let (absorption) = absorptions_.read(index);
        assert absorptions[index] = absorption;
        if (index == 0) {
            return ();
        }
        _read_absorptions_iter(index=index - 1, absorptions=absorptions);
        return ();
    }

    func _read_users{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        users_len: felt, users: felt*
    ) {
        alloc_locals;
        let (users_len) = users_len_.read();
        let (local users: felt*) = alloc();

        if (users_len == 0) {
            return (users_len=users_len, users=users,);
        }

        _read_users_iter(index=users_len - 1, users=users);
        return (users_len=users_len, users=users);
    }

    func _read_users_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, users: felt*
    ) {
        alloc_locals;
        let (user) = users_.read(index);
        assert users[index] = user;
        if (index == 0) {
            return ();
        }
        _read_users_iter(index=index - 1, users=users);
        return ();
    }

    func _total_claimed_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, users: felt*
    ) -> (total_claimed: felt) {
        alloc_locals;

        let user = users[index];
        let (claimed) = claimed_.read(user);

        if (index == 0) {
            return (total_claimed=claimed);
        }

        let (add) = _total_claimed_iter(index=index - 1, users=users);
        return (total_claimed=claimed + add);
    }

    func _total_claimable_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, users: felt*
    ) -> (total_claimable: felt) {
        alloc_locals;

        let user = users[index];
        let (claimable) = claimable_of(user);

        if (index == 0) {
            return (total_claimable=claimable);
        }

        let (add) = _total_claimable_iter(index=index - 1, users=users);
        return (total_claimable=claimable + add);
    }

    func _claimable{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        address: felt, time: felt
    ) -> (claimable: felt) {
        alloc_locals;

        let (contract_address) = carbonable_project_address_.read();
        let (total_supply_uint256) = IERC721Enumerable.totalSupply(
            contract_address=contract_address
        );

        // [Check] totalSupply is lower than 2**128
        let is_too_high = is_not_zero(total_supply_uint256.high);
        with_attr error_message("CarbonableOffseter: project total supply too high") {
            assert is_too_high = 0;
        }

        let total_supply = total_supply_uint256.low;

        if (total_supply == 0) {
            return (claimable=0,);
        }

        let index = total_supply - 1;
        let (claimable) = _claimable_iter(
            contract_address=contract_address, address=address, current_time=time, index=index
        );

        return (claimable=claimable,);
    }

    func _claimable_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        contract_address: felt, address: felt, current_time: felt, index: felt
    ) -> (claimable: felt) {
        alloc_locals;

        // Get registered owner of the current token index
        let (high, low) = split_felt(index);
        let index_uint256 = Uint256(low=low, high=high);
        let (token_id) = IERC721Enumerable.tokenByIndex(
            contract_address=contract_address, index=index_uint256
        );
        let (owner) = registered_owner_.read(token_id);
        let (time) = registered_time_.read(token_id);

        // Increment the counter if owner is the specified address
        let not_eq = is_not_zero(owner - address);
        let eq = 1 - not_eq;

        let (initial_absorption) = _compute_absorption(time=time);
        let (final_absorption) = _compute_absorption(time=current_time);

        // [Check] felt overflow
        let right_order = is_le(initial_absorption, final_absorption);
        with_attr error_message("CarbonableOffseter: Error while computing claimable") {
            assert right_order = TRUE;
        }
        let claimable = final_absorption - initial_absorption;

        // Stop if index is null
        if (index == 0) {
            return (claimable=claimable,);
        }

        // Else move on to next index
        let (add) = _claimable_iter(
            contract_address=contract_address,
            address=address,
            current_time=current_time,
            index=index - 1,
        );
        return (claimable=claimable + add,);
    }

    func _compute_absorption{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        time: felt
    ) -> (computed_absorption: felt) {
        alloc_locals;

        let (_, absorptions) = _read_absorptions();
        let (times_len, times) = _read_times();
        let (computed_absorption) = _compute_absorption_iter(
            time=time,
            index=times_len - 1,
            times=times,
            absorptions=absorptions,
            next_time=0,
            next_absorption=0,
        );
        return (computed_absorption=computed_absorption,);
    }

    func _compute_absorption_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        time: felt,
        index: felt,
        times: felt*,
        absorptions: felt*,
        next_time: felt,
        next_absorption: felt,
    ) -> (computed_absorption: felt) {
        let stored_time = times[index];
        let stored_absorption = absorptions[index];
        let is_after = is_le(stored_time, time);
        if (is_after == TRUE) {
            // [Check] first iteration
            if (next_time == 0) {
                return (computed_absorption=stored_absorption);
            }

            // [Check] exact time
            if (time == stored_time) {
                return (computed_absorption=stored_absorption);
            }

            // [Compute] linear interpolation
            // Overflow is riskless since time is < 1E10 and absorption is <1E12 which is << 1E38
            // y = [(xb - x) * ya + (x - xa) * yb] / (xb - xa)
            let den = next_time - stored_time;
            let alpha = next_time - time;
            let beta = time - stored_time;
            let num = alpha * stored_absorption + beta * next_absorption;

            // [Check] Zero division
            let den_not_zero = is_not_zero(den);
            with_attr error_message(
                    "CarbonableOffseter: division by zero, two consecutive times are equals") {
                assert den_not_zero = TRUE;
            }
            let (computed_absorption, _) = unsigned_div_rem(num, den);
            return (computed_absorption=computed_absorption);
        }

        // [Check] index is null
        if (index == 0) {
            return (computed_absorption=stored_absorption);
        }

        let (computed_absorption) = _compute_absorption_iter(
            time=time,
            index=index - 1,
            times=times,
            absorptions=absorptions,
            next_time=stored_time,
            next_absorption=stored_absorption,
        );
        return (computed_absorption=computed_absorption,);
    }
}
