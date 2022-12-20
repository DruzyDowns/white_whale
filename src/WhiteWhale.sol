// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

import "solady/utils/LibBitmap.sol";

contract WhiteWhale is ERC721, IERC721Receiver {
    struct Token {
        uint256 tokenId;
        address collection;
        address depositor;
        uint8 stealCounter;
    }

    // the pool of gifts that have been deposited
    Token[] giftPool;

    // Bitmap from giftPoolIndex to unwrapped status
    LibBitmap.Bitmap isUnwrapped;

    // maps tokenId to giftPoolIndex + 1
    mapping(uint256 => uint256) unwrappedGifts;

    uint256 roundCounter;
    uint256 stealCounter;

    enum GameState {
        NOT_STARTED,
        IN_PROGRESS,
        COMPLETED
    }

    GameState gameState;

    constructor() ERC721("WhiteWhale", "WW") {}

    function _pseudoRandom(uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty))) % max;
    }

    // deposit
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        require(gameState == GameState.NOT_STARTED, "Game has already started");
        require(balanceOf(from) == 0, "Already deposited gift");

        giftPool.push(Token(tokenId, msg.sender, from, 0));

        _safeMint(from, giftPool.length);

        return IERC721Receiver.onERC721Received.selector;
    }

    // start game
    function start() public {
        require(gameState == GameState.NOT_STARTED, "Game already started");
        gameState = GameState.IN_PROGRESS;
    }

    // end game
    function end() public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(roundCounter == giftPool.length, "Game has not been completed");

        gameState = GameState.COMPLETED;
    }

    // withdraw token
    function withdraw(uint256 tokenId) external {
        require(gameState == GameState.COMPLETED, "Game is not finished");

        uint256 giftIndex = unwrappedGifts[tokenId] - 1;

        Token memory gift = giftPool[giftIndex];

        IERC721(gift.collection).safeTransferFrom(
            address(this),
            ownerOf(tokenId),
            gift.tokenId
        );
    }

    // unwrapGift
    function unwrapGift(uint256 tokenId) public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(unwrappedGifts[tokenId] != 0, "Already unwrapped gift");
        require(ownerOf(tokenId) == msg.sender, "Not your turn");
        require(tokenId == roundCounter, "Not your turn");

        uint256 pseudoRandomIndex = _pseudoRandom(giftPool.length);

        for (uint256 i = 0; i < giftPool.length; i++) {
            uint256 currentIndex = (pseudoRandomIndex + i) % giftPool.length;
            bool isIndexUnwrapped = LibBitmap.get(isUnwrapped, currentIndex);

            if (
                isIndexUnwrapped &&
                giftPool[currentIndex].depositor != msg.sender
            ) {
                unwrappedGifts[tokenId] = currentIndex + 1;
            }
        }

        stealCounter = 0;
        roundCounter += 1;
    }

    // stealGift
    function stealGift(uint256 tokenId, uint256 targetTokenId) public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(unwrappedGifts[tokenId] != 0, "Already unwrapped gift");
        require(
            stealCounter < 3,
            "Cannot steal more than three times in a row"
        );

        address giftHolder = ownerOf(targetTokenId);

        require(giftHolder != msg.sender, "Cannot steal gift from yourself");
        require(unwrappedGifts[tokenId] != 0, "No gift to steal");
        require(
            giftPool[unwrappedGifts[tokenId] - 1].stealCounter < 3,
            "Gift cannot be stolen more than three times"
        );
        require(
            giftPool[unwrappedGifts[tokenId] - 1].depositor != msg.sender,
            "Cannot steal your own gift"
        );
        require(ownerOf(tokenId) == msg.sender, "Not your turn");
        require(tokenId == roundCounter, "Not your turn");

        unwrappedGifts[tokenId] = unwrappedGifts[targetTokenId];
        delete unwrappedGifts[targetTokenId];
        giftPool[unwrappedGifts[targetTokenId] - 1].stealCounter += 1;

        stealCounter += 1;
        roundCounter = targetTokenId;
    }
}
