// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TaffyERC20 is ERC20 {
    address raiseContractAddress;
    uint public maxSupply;

    constructor(string memory name, string memory ticker, uint _maxSupply) ERC20(name, ticker) payable {
        raiseContractAddress = msg.sender;
        maxSupply = _maxSupply;
    }

    function mint(address _account, uint _amount) public {
        require(msg.sender == raiseContractAddress, "You may only mint from the Raise Contract");
        _mint(_account, _amount);
    }


    receive() external payable {}
    fallback() external payable {}
}