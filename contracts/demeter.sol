// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Demeter {
    address public daoMultisig;
    address public acceptedPayTokenAddress;
    uint256 public erc20Count;

    struct demeterDeposits {
        uint256 depositTimestamp;
        address depositor;
        uint256 amount;
    }
    mapping(address => mapping(uint256 => demeterDeposits)) public depositorsDemeterList;

    struct TokenDepositedEntry {
        address depositorAddress;
        address tokenAddress;
        uint256 tokenId;
        uint256 amount;
    }
    TokenDepositedEntry[] public addressWithTokens;

    event TokenDepositedUpdate(address tokenAddress, uint256 tokenId);
    event TokenRemovedUpdate(address tokenAddress, uint256 tokenId);

    constructor() {
        daoMultisig = msg.sender;
        acceptedPayTokenAddress = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
        erc20Count = 0;
    }

    function addERC721ToPool(address tokenAddress, uint256 tokenId) public {
        IERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId);

        depositorsDemeterList[tokenAddress][tokenId] = demeterDeposits(block.timestamp, msg.sender, 1);

        addressWithTokens.push(TokenDepositedEntry(msg.sender, tokenAddress, tokenId, 1));

        emit TokenDepositedUpdate(tokenAddress, tokenId);
    }

    function removeERC721FromPool(address tokenAddress, uint256 tokenId) public {
        if(msg.sender!=daoMultisig) {
            require(depositorsDemeterList[tokenAddress][tokenId].depositor == msg.sender, 'Remove: Only the depositor or DAO multisig can perform this action');
        }

        // check if needs approval as some tokens fail due this
        (bool success,) = tokenAddress.call(abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            tokenId
        ));
        if (success) {
            IERC721(tokenAddress).approve(address(this), tokenId);
        }

        IERC721(tokenAddress).transferFrom(address(this), msg.sender, tokenId);

        depositorsDemeterList[tokenAddress][tokenId] = demeterDeposits(0, address(0), 0);

        emit TokenRemovedUpdate(tokenAddress, tokenId);
    }

    function addERC20ToPool(uint256 amount) public {
        erc20Count = erc20Count++;

        IERC20(acceptedPayTokenAddress).transferFrom(msg.sender, address(this), amount);

        depositorsDemeterList[acceptedPayTokenAddress][erc20Count] = demeterDeposits(block.timestamp, msg.sender, amount);

        addressWithTokens.push(TokenDepositedEntry(msg.sender, acceptedPayTokenAddress, erc20Count, amount));

        emit TokenDepositedUpdate(acceptedPayTokenAddress, erc20Count);
    }

    function removeERC20FromPool(uint256 count) public {
        if(msg.sender!=daoMultisig) {
            require(depositorsDemeterList[acceptedPayTokenAddress][count].depositor == msg.sender, 'Remove: Only the depositor or DAO multisig can perform this action');
        }

        IERC20(acceptedPayTokenAddress).transferFrom(address(this), msg.sender, depositorsDemeterList[acceptedPayTokenAddress][count].amount);

        depositorsDemeterList[acceptedPayTokenAddress][count] = demeterDeposits(0, address(0), 0);

        emit TokenRemovedUpdate(acceptedPayTokenAddress, erc20Count);
    }
}