cast send --account nani --rpc-url https://rpc.ankr.com/eth 0x0000000000FFe8B47B3e2130213B802212439497 "safeCreate2(bytes32,bytes)" 0x999657a41753b8e69c66e7b1a8e37d513cb44e1c7f52b89af179ea02b3ce6703 $(forge inspect Token bytecode)
forge verify-contract 0x0000000000004323109DB770bBB677A40E22158E Token --watch
