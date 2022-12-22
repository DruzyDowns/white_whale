// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";

import "../src/WhiteWhale.sol";
import "../src/WhiteWhaleFactory.sol";

contract WhiteWhaleTests is Test {
    WhiteWhale implementation;
    WhiteWhaleFactory factory;

    function setUp() public {
        implementation = new WhiteWhale();
        factory = new WhiteWhaleFactory(address(implementation));
    }

    function testWhiteWhaleDeployment() public {
        address clone = factory.deploy("White Whale Party", "WWP");
        assertTrue(clone != address(0));

        assertEq(ERC721(clone).name(), "White Whale Party");
        assertEq(ERC721(clone).symbol(), "WWP");
    }

    function testWhiteWhaleMinting() public {
        address clone = factory.deploy("White Whale Party", "WWP");
        TokenCollection tokenCollection = new TokenCollection();

        address user1 = vm.addr(1);

        tokenCollection.mint(user1, 1);

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, clone, 1);

        assertEq(tokenCollection.ownerOf(1), clone);
        assertEq(ERC721(clone).ownerOf(1), user1);
    }
}

contract TokenCollection is ERC721 {
    constructor() ERC721("TokenCollection", "TC") {}

    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
