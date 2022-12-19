// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

contract WhiteWhale is ERC721, IERC721Receiver {
    struct Token {
        address collection;
        uint256 tokenId;
        address depositor;
    }

    uint256 tokenIdCounter;
    uint256 turnCounter = 1;

    mapping(uint256 => Token) wrappedGifts;
    mapping(address => Token) unwrappedGifts;

    constructor() ERC721("WhiteWhale", "WW") {}

    // deposit
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        require(balanceOf(from) == 0, "Already deposited token");

        uint256 nextTokenId = ++tokenIdCounter;

        _safeMint(from, nextTokenId);

        wrappedGifts[nextTokenId] = Token(msg.sender, tokenId, from);

        return IERC721Receiver.onERC721Received.selector;
    }

    // unwrapGift
    function unwrapGift(uint256 giftTokenId, uint256 senderTokenId) public {
        require(
            unwrappedGifts[msg.sender].collection == address(0),
            "Already unwrapped gift"
        );
        require(ownerOf(senderTokenId) == msg.sender, "Invalid senderTokenId");
        require(senderTokenId == turnCounter, "Not your turn");
        require(
            wrappedGifts[giftTokenId].collection != address(0),
            "Invalid giftTokenId"
        );
        require(
            wrappedGifts[giftTokenId].depositor != msg.sender,
            "Cannot unwrap own gift"
        );

        unwrappedGifts[msg.sender] = wrappedGifts[giftTokenId];

        delete wrappedGifts[giftTokenId];
    }

    // stealGift
    function stealGift(address giftHolder) public {
        // requires here...

        Token memory giftToSteal = unwrappedGifts[giftHolder];
        unwrappedGifts[giftHolder] = unwrappedGifts[msg.sender];
        unwrappedGifts[msg.sender] = giftToSteal;

        turnCounter = ++turnCounter;
    }
}