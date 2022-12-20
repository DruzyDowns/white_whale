// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

import "solady/utils/LibBitmap.sol";

contract WhiteWhale is ERC721, IERC721Receiver {
    struct Gift {
        uint256 tokenId;
        address collection;
        address depositor;
        uint8 stealCounter;
    }

    // the pool of gifts that have been deposited
    Gift[] gifts;

    // Bitmap from giftPoolIndex to unwrapped status
    LibBitmap.Bitmap isClaimed;

    // maps tokenId to giftPoolIndex + 1
    mapping(uint256 => uint256) claimedGifts;

    uint256 roundCounter;
    uint256 stealCounter;

    enum GameState {
        NOT_STARTED,
        IN_PROGRESS,
        COMPLETED
    }

    GameState gameState;

    constructor() ERC721("WhiteWhale", "WW") {}

    // deposit
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        require(gameState == GameState.NOT_STARTED, "Game has already started");
        require(balanceOf(from) == 0, "Already deposited gift");

        gifts.push(Gift(tokenId, msg.sender, from, 0));

        _safeMint(from, gifts.length);

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
        require(roundCounter == gifts.length, "Game has not been completed");

        gameState = GameState.COMPLETED;
    }

    // withdraw token
    function withdraw(uint256 tokenId) external {
        require(gameState == GameState.COMPLETED, "Game is not finished");

        uint256 giftIndex = claimedGifts[tokenId] - 1;

        Gift memory gift = gifts[giftIndex];

        IERC721(gift.collection).safeTransferFrom(
            address(this),
            ownerOf(tokenId),
            gift.tokenId
        );
    }

    // unwrapGift
    function claimGift(uint256 tokenId, uint256 targetGiftIndex) public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(claimedGifts[tokenId] != 0, "Already unwrapped gift");
        require(ownerOf(tokenId) == msg.sender, "Not your turn");
        require(tokenId == roundCounter, "Not your turn");
        require(
            !LibBitmap.get(isClaimed, targetGiftIndex),
            "Gift has already been claimed"
        );

        claimedGifts[tokenId] = targetGiftIndex + 1;
        LibBitmap.set(isClaimed, targetGiftIndex);

        stealCounter = 0;
        roundCounter += 1;
    }

    // stealGift
    function stealGift(uint256 tokenId, uint256 targetTokenId) public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(claimedGifts[tokenId] != 0, "Already unwrapped gift");
        require(
            stealCounter < 3,
            "Cannot steal more than three times in a row"
        );

        address giftHolder = ownerOf(targetTokenId);

        require(giftHolder != msg.sender, "Cannot steal gift from yourself");
        require(claimedGifts[tokenId] != 0, "No gift to steal");
        require(
            gifts[claimedGifts[tokenId] - 1].stealCounter < 3,
            "Gift cannot be stolen more than three times"
        );
        require(
            gifts[claimedGifts[tokenId] - 1].depositor != msg.sender,
            "Cannot steal your own gift"
        );
        require(ownerOf(tokenId) == msg.sender, "Not your turn");
        require(tokenId == roundCounter, "Not your turn");

        claimedGifts[tokenId] = claimedGifts[targetTokenId];
        delete claimedGifts[targetTokenId];
        gifts[claimedGifts[targetTokenId] - 1].stealCounter += 1;

        stealCounter += 1;
        roundCounter = targetTokenId;
    }
}
