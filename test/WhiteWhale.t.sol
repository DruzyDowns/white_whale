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
        factory = new WhiteWhaleFactory(
            address(implementation),
            "https://whitewhale.party/api/metadata/"
        );
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

    function testGameLogic() public {
        address clone = factory.deploy("White Whale Party", "WWP");
        TokenCollection tokenCollection = new TokenCollection();

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        address user3 = vm.addr(3);

        tokenCollection.mint(user1, 1);
        tokenCollection.mint(user2, 2);
        tokenCollection.mint(user3, 3);

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, clone, 1);

        vm.prank(user2);
        tokenCollection.safeTransferFrom(user2, clone, 2);

        vm.prank(user3);
        tokenCollection.safeTransferFrom(user3, clone, 3);

        assertEq(tokenCollection.ownerOf(1), clone);
        assertEq(ERC721(clone).ownerOf(1), user1);
        assertEq(tokenCollection.ownerOf(2), clone);
        assertEq(ERC721(clone).ownerOf(2), user2);
        assertEq(tokenCollection.ownerOf(3), clone);
        assertEq(ERC721(clone).ownerOf(3), user3);

        WhiteWhale party = WhiteWhale(clone);

        party.start();

        // user one claims gift deposited by user three
        vm.prank(user1);
        party.claimGift(1, 2);
        WhiteWhale.Gift memory claimedGift1 = party.getGiftByTokenId(1);
        assertEq(claimedGift1.tokenId, 3);

        // user two steals user three's gift from user one
        vm.prank(user2);
        party.stealGift(2, 1);
        WhiteWhale.Gift memory stolenGift1 = party.getGiftByTokenId(2);
        assertEq(stolenGift1.tokenId, 3);

        // should now be user one's turn because they were stolen from
        assertEq(party.getCurrentTurn(), 1);

        // user one claims user two's gift
        vm.prank(user1);
        party.claimGift(1, 1);
        WhiteWhale.Gift memory claimedGift2 = party.getGiftByTokenId(1);
        assertEq(claimedGift2.tokenId, 2);

        // user three claims user one's gift
        vm.prank(user3);
        party.claimGift(3, 0);
        WhiteWhale.Gift memory glaimedGift3 = party.getGiftByTokenId(3);
        assertEq(glaimedGift3.tokenId, 1);

        // game ends
        party.end();

        // user one withdraws user two's gift
        vm.prank(user1);
        party.withdraw(1);
        assertEq(tokenCollection.ownerOf(2), user1);

        // user two withdraws user three's gift
        vm.prank(user2);
        party.withdraw(2);
        assertEq(tokenCollection.ownerOf(3), user2);

        // user three withdraws user one's gift
        vm.prank(user3);
        party.withdraw(3);
        assertEq(tokenCollection.ownerOf(1), user3);
    }

    function testCanBork() public {
        address clone = factory.deploy("White Whale Party", "WWP");
        TokenCollection tokenCollection = new TokenCollection();

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        address user3 = vm.addr(3);

        tokenCollection.mint(user1, 3);
        tokenCollection.mint(user2, 1);
        tokenCollection.mint(user3, 2);

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, clone, 3);

        vm.prank(user2);
        tokenCollection.safeTransferFrom(user2, clone, 1);

        vm.prank(user3);
        tokenCollection.safeTransferFrom(user3, clone, 2);

        WhiteWhale party = WhiteWhale(clone);
        party.bork();

        vm.prank(user1);
        party.withdraw(1);
        assertEq(tokenCollection.ownerOf(3), user1);

        vm.prank(user2);
        party.withdraw(2);
        assertEq(tokenCollection.ownerOf(1), user2);

        vm.prank(user3);
        party.withdraw(3);
        assertEq(tokenCollection.ownerOf(2), user3);
    }

    function testOwnable() public {
        address user1 = vm.addr(1);

        vm.prank(user1);
        address clone = factory.deploy("White Whale Party", "WWP");

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        WhiteWhale(clone).bork();

        vm.prank(user1);
        WhiteWhale(clone).bork();
    }

    function testTokenURI() public {
        address user1 = vm.addr(1);

        address clone = factory.deploy("White Whale Party", "WWP");
        TokenCollection tokenCollection = new TokenCollection();

        tokenCollection.mint(user1, 1);

        vm.prank(user1);
        tokenCollection.safeTransferFrom(user1, clone, 1);

        string memory tokenURI = WhiteWhale(clone).tokenURI(1);
        console.log(tokenURI);
    }
}

contract TokenCollection is ERC721 {
    constructor() ERC721("TokenCollection", "TC") {}

    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
