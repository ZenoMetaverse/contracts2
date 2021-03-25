const { assert } = require("chai");

const RuneToken = artifacts.require('RuneToken');

contract('RuneToken', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.rune = await RuneToken.new({ from: minter });
    });


    it('mint', async () => {
        await this.rune.mint(alice, 1000, { from: minter });
        assert.equal((await this.rune.balanceOf(alice)).toString(), '1000');
    })
});
