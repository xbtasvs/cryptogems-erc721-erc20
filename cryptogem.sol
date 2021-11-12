// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './yieldtoken.sol';

contract NFTCRYPTOGEMS is ERC721Enumerable, Ownable {
  using Strings for uint256;

  string baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0.0777 ether;
  uint256 public maxSupply = 12;
  uint public giftPercentage = 10;
  uint256 public maxMintAmount = 20;
  uint256 public headStart = block.timestamp + 1 days;
  bool public paused = false;
  bool public revealed = false;
  string public notRevealedUri;
  address payable public ultimateGiftAddress;
  YieldToken public yieldToken;
  mapping(address => uint256) public balanceOG;
  bool public middlePay = false;
  bool public finalPay = false;
  constructor(
    string memory _initBaseURI,
    string memory _initNotRevealedUri
  ) ERC721("NFTCRYPTOGEMS", "NFTCG") {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

	function setYieldToken(address _yield) external onlyOwner {
		yieldToken = YieldToken(_yield);
	}  

	function getReward() external {
		yieldToken.updateReward(msg.sender, address(0), 0);
		yieldToken.getReward(msg.sender);
	}

	function transferFrom(address from, address to, uint256 tokenId) public override {
		yieldToken.updateReward(from, to, tokenId);
    balanceOG[from]--;
    balanceOG[to]++;
		ERC721.transferFrom(from, to, tokenId);
	}
  // public
  function mint(uint256 _mintAmount) public payable { 
    uint256 supply = totalSupply();   
    require(!paused, "Contract is paused!");
    require(_mintAmount > 0, "mintAmount > 0");
    require(_mintAmount <= maxMintAmount, "amount less that maxmintamount");
    require(supply + _mintAmount <= maxSupply, "supply amount exceed");
    require(msg.sender != owner(), "Owner can not mint!");
    require(msg.value >= cost, "Not enough funds!");
    
    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }
    address payable giftAddress = payable(msg.sender);
    uint256 giftValue;
    
    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }
    if(supply > 0) {
        giftAddress = payable(ownerOf(randomNum(supply, block.timestamp, supply + 1) + 1));
        giftValue = msg.value * giftPercentage / 100; //supply + 1 == maxSupply ? address(this).balance * giftPercentage / 100 : (last code)
        if(supply + 1 == maxSupply) {
          ultimateGiftAddress = giftAddress;
            // (bool success, ) = payable(owner()).call{value: 1 ether}("");
        }
    }
    yieldToken.updateReward(msg.sender, address(0), 0);
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);

      if(supply > 0) {
          (bool success, ) = payable(giftAddress).call{value: giftValue}("");
          require(success, "Could not send value!");
      }
    }
    if((supply + _mintAmount) * 2 >= maxSupply && middlePay == false) {
      middlePay = true;
      (bool success, ) = payable(0x2F20D2cafaa1692e401791Be811700fb56f0930B).call{value: 1.08 ether}("");
      require(success, "Could not send value1111");
    }

    balanceOG[msg.sender] += _mintAmount;
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }
  
  function randomNum(uint256 _mod, uint256 _seed, uint256 _salt) public view returns(uint256) {
      uint256 num = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _seed, _salt))) % _mod;
      return num;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    if(revealed == false) {
        return notRevealedUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  //only owner
  function reveal() public onlyOwner() {
      revealed = true;
  }
  
  function setCost(uint256 _newCost) public onlyOwner() {
    cost = _newCost;
  }

  function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
    notRevealedUri = _notRevealedURI;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
   function setGiftPercentage (uint256 _newPercentage) public onlyOwner(){
        giftPercentage = _newPercentage;
    }
  
  function withdraw() public payable onlyOwner {
    uint256 supply = totalSupply();
    require(supply == maxSupply || block.timestamp >= headStart, "Can not withdraw yet.");
    if(finalPay == false || address(this).balance > 1 ether) {
      finalPay = true;
      (bool d, ) = payable(0x2F20D2cafaa1692e401791Be811700fb56f0930B).call{value: 1 ether}("");
      require(d);      
    }
    (bool s, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(s);
  }
}
