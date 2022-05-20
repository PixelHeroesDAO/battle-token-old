/* メッセージ署名の方法の確認テストスクリプト
    **署名プロセス
    1.ウォレットにプライベートキーを入れてsignerを用意（署名の準備）
    2.署名するメッセージを用意
    3.ハッシュメッセージを作成。id関数を使うといろいろutfの処理だとかをまるっとやってくれる模様
    4.ハッシュメッセージをarrayify関数でバイト形式ハッシュメッセージに変換
    5.signerにバイト形式ハッシュメッセージへ署名させる
    **検証プロセス
    1.バイト形式ハッシュメッセージを用意（この場合上で用意済み）
    2.verifyMessage関数にバイト形式ハッシュメッセージと署名を渡すと復号アドレスが返る
    3.復号アドレスとsigner公開アドレスの一致を確認
    **solidity復号
    1.メッセージ内容にkeccak256でハッシュを取る
    2.フロントから送られてきたsignatureでアドレスを復号する
      (hashにprefixを付けて、全体をkeccak256を取ったbytes32 digestをECDSA.recoverに渡す)
*/
const ethers = require('ethers');
const main = async () => {
    const allowlistedAddresses = [
        '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc',
        '0x90f79bf6eb2c4f870365e785982e1f101e93b906',
        '0x15d34aaf54267db7d7c367839aaf71a00a2c6a65',
        '0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc',
    ];
    const owner = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266';

    const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

    const signer = new ethers.Wallet(privateKey);
    console.log(signer.address)

    // Get first allowlisted address
    let message = "テスト";
    console.log(message);

    // Compute hash of the address
    let messageHash = ethers.utils.id(message);
    console.log("Message Hash: ", messageHash);

    // Sign the hashed address
    let messageBytes = ethers.utils.arrayify(messageHash);
    let signature = await signer.signMessage(messageBytes);
    console.log("Signature: ", signature);
    
    //メッセージハッシュのバイトコードで検証する必要がある
    let recoveredAddress = ethers.utils.verifyMessage(messageBytes, signature);
    console.log(recoveredAddress);
    console.log("veryfication:", recoveredAddress == signer.address);

    //コントラクトでの復号の確認
    const nftContractFactory = await hre.ethers.getContractFactory('BattleToken');
    const nftContract = await nftContractFactory.deploy();
    
    await nftContract.deployed();
    
    console.log("Contract deployed by: ", signer.address);
    recover = await nftContract.recoverSigner(messageHash, signature);
    console.log("Message was signed by: ", recover.toString() , " message:", message);

    //追加テスト
    let sigfunc = await nftContract.SIG_MINT();
    let msgFront = allowlistedAddresses[0]+"|"+"0"+"|"+"1"+"|"+"1"+"|"+sigfunc+"|"+"2000";
    console.log("msgFront:", msgFront);
    let msgFrontHash = ethers.utils.id(msgFront);
    let msgFrontBytes = ethers.utils.arrayify(msgFrontHash);
    let msgContr = await nftContract._makeMessage(allowlistedAddresses[0],1,1,await nftContract.SIG_MINT(), 2000);
    console.log("msgContr:", msgContr);

    signature = await signer.signMessage(msgFrontBytes);

    recover = await nftContract.recoverSigner(ethers.utils.arrayify(ethers.utils.id(msgContr)), signature);
    console.log("Message was signed by: ", recover.toString());
    //messageHash = await nftContract._makeSignHash(allowlistedAddresses[0],1,1,await nftContract.SIG_MINT(), 2000);
    //console.log (messageHash);
}

const runMain = async () => {
    try {
        await main(); 
        process.exit(0);
    }
    catch (error) {
        console.log(error);
        process.exit(1);
    }
};

runMain();