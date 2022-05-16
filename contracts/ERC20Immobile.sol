// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 * 
 * CHANGE in ERC20Immobile.sol:
 *   derived for immobile ERC20 Abstract contract.
 */
abstract contract ERC20Immobile is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     * change to abstract.
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
     */

    /**
     * @dev See {IERC20-balanceOf}.
     * change to abstract.
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
     */

    /**
     * @dev See {IERC20-transfer}.
     *
     * Implementation of ERC20 was eliminated and always return false.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return false;
    }

    /**
     * @dev See {IERC20-allowance}.
     *
     * Implementation of ERC20 was eliminated and always 0.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return 0;
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Implementation of ERC20 was eliminated and always false.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        return false;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Implementation of ERC20 was eliminated and always false.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return false;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     *
     * Implementation of ERC20 was eliminated and always false.
     */    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        return false;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     *
     * Implementation of ERC20 was eliminated and always false.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        return false;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * Implementation of ERC20 was eliminated.
     
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        
    }
     */
     
    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Implementation of ERC20 was eliminated.
    function _mint(address account, uint256 amount) internal virtual {

    }
     */

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Implementation of ERC20 was eliminated.
    function _burn(address account, uint256 amount) internal virtual {

    }
     */

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     *
     * Implementation of ERC20 was eliminated.
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {

    }
     */

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Implementation of ERC20 was eliminated.
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
     */

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Implementation of ERC20 was eliminated.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
     */

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Implementation of ERC20 was eliminated.
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
     */
}