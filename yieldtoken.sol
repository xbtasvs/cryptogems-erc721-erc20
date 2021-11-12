// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IDustz {
	function balanceOG(address _user) external view returns(uint256);
}
contract YieldToken is ERC20("Dustz", "DTZ") {

	uint256 constant public BASE_RATE = 10; 
	uint256 constant public INITIAL_ISSUANCE = 300;
	// Tue Mar 18 2031 17:46:47 GMT+0000
	uint256 constant public END = 1931622407;

	mapping(address => uint256) public rewards;
	mapping(address => uint256) public lastUpdate;

	IDustz public  cryptogemsContract;

	event RewardPaid(address indexed user, uint256 reward);

	constructor(address _cryptogems) {
		cryptogemsContract = IDustz(_cryptogems);
	}


	function min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}

	// called when minting many NFTs
	// updated_amount = (balanceOG(user) * base_rate * delta / 86400) + amount * initial rate
	function updateRewardOnMint(address _user, uint256 _amount) external {
		require(msg.sender == address(cryptogemsContract), "Can't call this");
		uint256 time = min(block.timestamp, END);
		uint256 timerUser = lastUpdate[_user];
		if (timerUser > 0)
			rewards[_user] = rewards[_user] + cryptogemsContract.balanceOG(_user) * BASE_RATE * (time - timerUser) / 86400 + _amount * INITIAL_ISSUANCE;
		else 
			rewards[_user] = rewards[_user] + _amount * INITIAL_ISSUANCE;
		lastUpdate[_user] = time;
	}

	// called on transfers
	function updateReward(address _from, address _to, uint256 _tokenId) external {
		require(msg.sender == address(cryptogemsContract));
		if (_tokenId < 1001) {
			uint256 time = min(block.timestamp, END);
			uint256 timerFrom = lastUpdate[_from];
			if (timerFrom > 0)
				rewards[_from] += cryptogemsContract.balanceOG(_from) * BASE_RATE * (time - timerFrom) / 86400;
			else
			  lastUpdate[_from] = time;
			if (timerFrom != END)
				lastUpdate[_from] = time;
			if (_to != address(0)) {
				uint256 timerTo = lastUpdate[_to];
				if (timerTo > 0)
					rewards[_to] += cryptogemsContract.balanceOG(_to) * BASE_RATE * (time - timerTo) / 86400;
				if (timerTo != END)
					lastUpdate[_to] = time;
			}
		}
	}

	function getReward(address _to) external {
		require(msg.sender == address(cryptogemsContract), "Not cryptogemsContract");
		uint256 reward = rewards[_to];
		if (reward > 0) {
			rewards[_to] = 0;
			_mint(_to, reward);
			emit RewardPaid(_to, reward);
		}
	}

	function burn(address _from, uint256 _amount) external {
		require(msg.sender == address(cryptogemsContract));
		_burn(_from, _amount);
	}

	function getTotalClaimable(address _user) external view returns(uint256) {
		uint256 time = min(block.timestamp, END);
		uint256 pending = cryptogemsContract.balanceOG(_user) * BASE_RATE * (time - lastUpdate[_user]) / 86400;
		return rewards[_user] + pending;
	}
}