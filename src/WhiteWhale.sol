// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";

import "solady/utils/LibBitmap.sol";

contract WhiteWhale is Initializable, ERC721, IERC721Receiver {
    // Token name
    string name;

    // Token symbol
    string symbol;

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

    event GameStarted();
    event GameEnded();
    event GiftDeposited(address depositor, address collection, uint256 tokenId);
    event GiftClaimed(address claimer, uint256 giftIndex);
    event GiftStolen(address stealer, address victim, uint256 giftIndex);
    event GiftWithdrawn(
        address withdrawer,
        address collection,
        uint256 tokenId
    );

    constructor() ERC721("WhiteWhale", "WW") {}

    function initialize(string memory name_, string memory symbol_)
        public
        initializer
    {
        name = name_;
        symbol = symbol_;
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

        gifts.push(Gift(tokenId, msg.sender, from, 0));

        _safeMint(from, gifts.length);

        emit GiftDeposited(from, msg.sender, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        require(
            gameState == GameState.COMPLETED,
            "Tokens are locked until game is over"
        );

        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    // start game
    function start() public {
        require(gameState == GameState.NOT_STARTED, "Game already started");
        gameState = GameState.IN_PROGRESS;

        emit GameStarted();
    }

    // end game
    function end() public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(roundCounter == gifts.length, "Game has not been completed");

        gameState = GameState.COMPLETED;
        emit GameEnded();
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

        emit GiftWithdrawn(ownerOf(tokenId), gift.collection, gift.tokenId);
    }

    function hasClaimedGift(uint256 tokenId) public view returns (bool) {
        return claimedGifts[tokenId] != 0;
    }

    function getGiftIndex(uint256 tokenId) public view returns (uint256) {
        return claimedGifts[tokenId] - 1;
    }

    function setGiftIndex(uint256 tokenId, uint256 giftIndex) public {
        claimedGifts[tokenId] = giftIndex + 1;
    }

    // claimGift
    function claimGift(uint256 tokenId, uint256 targetGiftIndex) public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(!hasClaimedGift(tokenId), "Already unwrapped gift");
        require(ownerOf(tokenId) == msg.sender, "Not your turn");
        require(tokenId == roundCounter, "Not your turn");
        require(
            !LibBitmap.get(isClaimed, targetGiftIndex),
            "Gift has already been claimed"
        );

        setGiftIndex(tokenId, targetGiftIndex);
        LibBitmap.set(isClaimed, targetGiftIndex);

        stealCounter = 0;
        roundCounter += 1;

        emit GiftClaimed(msg.sender, targetGiftIndex);
    }

    // stealGift
    function stealGift(uint256 tokenId, uint256 targetTokenId) public {
        require(gameState == GameState.IN_PROGRESS, "Game is not in progress");
        require(!hasClaimedGift(tokenId), "Already unwrapped gift");
        require(
            stealCounter < 3,
            "Cannot steal more than three times in a row"
        );

        address giftHolder = ownerOf(targetTokenId);
        uint256 currentGiftIndex = getGiftIndex(tokenId);

        require(giftHolder != msg.sender, "Cannot steal gift from yourself");
        require(hasClaimedGift(targetTokenId), "No gift to steal");
        require(
            gifts[currentGiftIndex].stealCounter < 3,
            "Gift cannot be stolen more than three times"
        );
        require(
            gifts[currentGiftIndex].depositor != msg.sender,
            "Cannot steal your own gift"
        );
        require(ownerOf(tokenId) == msg.sender, "Not your turn");
        require(tokenId == roundCounter, "Not your turn");

        uint256 giftIndex = getGiftIndex(targetTokenId);
        setGiftIndex(tokenId, giftIndex);
        delete claimedGifts[targetTokenId];

        gifts[giftIndex].stealCounter += 1;

        stealCounter += 1;
        roundCounter = targetTokenId;

        emit GiftStolen(msg.sender, giftHolder, giftIndex);
    }
}
