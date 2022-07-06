
import UIKit

@available(iOS 14.0, *)
class ViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var displayView: UIImageView!
    
    var sourceImg: UIImage! {
        didSet {
            displayView.image = sourceImg
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sourceImg = UIImage.init(named: "input1_029.jpg")!
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
 
    }
 
    @IBAction func handlePickerTap(_ sender: Any) {
        actionSheetAlert()
    }
    
    @IBAction func handleSegmentTap(_ sender: Any) {
        if let cgImg = sourceImg.segmentation(){
            displayView.image = UIImage(cgImage: cgImg)

        }
    }
    
    @IBAction func handelGrayTap(_ sender: Any) {
        if let cgImg = sourceImg.segmentation(){
            let filter = BlackSegmentFilter()
            filter.inputImage = CIImage.init(cgImage: sourceImg.cgImage!)
            filter.maskImage = CIImage.init(cgImage: cgImg)
            let output = filter.value(forKey:kCIOutputImageKey) as! CIImage
            
            let ciContext = CIContext(options: nil)
            let cgImage = ciContext.createCGImage(output, from: output.extent)!
            displayView.image = UIImage(cgImage: cgImage)
        }
    }
    
}

//https://hururuek-chapchap.tistory.com/64 참고
// UIImagePickerControllerDelegate = 카메라 롤이나 앨범에서 사진을 가져올 수 있도록 도와 주는 것
@available(iOS 14.0, *)
extension ViewController : UIImagePickerControllerDelegate , UINavigationControllerDelegate{

    func actionSheetAlert(){
        
        let alert = UIAlertController(title: "선택", message: "선택", preferredStyle: .actionSheet)
        
        let cancel = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let camera = UIAlertAction(title: "카메라", style: .default) { [weak self] (_) in
            self?.presentCamera()
        }
        let album = UIAlertAction(title: "앨범", style: .default) { [weak self] (_) in
            self?.presentAlbum()
        }
        
        alert.addAction(cancel)
        alert.addAction(camera)
        alert.addAction(album)
        
        present(alert, animated: true, completion: nil)
        
    }
    
    func presentCamera(){
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
//        vc.allowsEditing =true 하면 무저건 정사각형 crop
//        vc.allowsEditing = true
        
        present(vc, animated: true, completion: nil)
    }
    
    func presentAlbum(){
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
//        vc.allowsEditing = true
        
        present(vc, animated: true, completion: nil)
    }
    
//    https://silver-g-0114.tistory.com/44 참고
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {    // 수정된 이미지가 있을 경우
            sourceImg = pickedImage.resize(size: CGSize(width: 1200, height: 1200 * (pickedImage.size.height / pickedImage.size.width)))
        }
        else if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {   // 원본 이미지가 있을 경우
            sourceImg = pickedImage.resize(size: CGSize(width: 1200, height: 1200 * (pickedImage.size.height / pickedImage.size.width)))
        }
        picker.dismiss(animated: true, completion: nil) // picker를 닫아줌
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
