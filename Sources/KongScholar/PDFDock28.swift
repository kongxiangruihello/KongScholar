import AppKit
import PDFKit
import KongScholarCore

/// A native PDF pane shares the manuscript window. Web content never receives PDF file access.
final class PDFDock28:NSObject {
    let split=NSSplitView(frame:.zero)
    let pane=NSView(frame:.zero)
    let viewer=PDFView(frame:.zero)
    let label=NSTextField(labelWithString:"")
    weak var owner:AppDelegate?
    var indexID="",sha256=""
    var observer:NSObjectProtocol?
    var loading=false
    init(owner:AppDelegate){
        self.owner=owner;super.init()
        split.isVertical=true;split.dividerStyle = .thin
        split.autoresizingMask=[.width,.height]
        let bar=NSStackView();bar.orientation = .horizontal;bar.spacing=8
        for(title,action)in [("上一页",#selector(previousPage)),("下一页",#selector(nextPage)),("收起原页",#selector(closePane))]{let b=NSButton(title:title,target:self,action:action);bar.addArrangedSubview(b)}
        bar.addArrangedSubview(label);label.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
        viewer.autoScales=true;viewer.displayMode = .singlePageContinuous;viewer.displayDirection = .vertical;viewer.backgroundColor = .windowBackgroundColor
        pane.addSubview(bar);pane.addSubview(viewer);bar.translatesAutoresizingMaskIntoConstraints=false;viewer.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([bar.leadingAnchor.constraint(equalTo:pane.leadingAnchor,constant:10),bar.trailingAnchor.constraint(equalTo:pane.trailingAnchor,constant:-10),bar.topAnchor.constraint(equalTo:pane.topAnchor,constant:10),bar.heightAnchor.constraint(equalToConstant:28),viewer.leadingAnchor.constraint(equalTo:pane.leadingAnchor),viewer.trailingAnchor.constraint(equalTo:pane.trailingAnchor),viewer.topAnchor.constraint(equalTo:bar.bottomAnchor,constant:8),viewer.bottomAnchor.constraint(equalTo:pane.bottomAnchor)])
        observer=NotificationCenter.default.addObserver(forName:.PDFViewPageChanged,object:viewer,queue:.main){[weak self]_ in self?.pageChanged()}
    }
    deinit{if let observer{NotificationCenter.default.removeObserver(observer)}}
    func show(document:PDFDocument,id:String,hash:String,page:Int){
        guard let owner,let target=document.page(at:page-1) else{return}
        loading=true;indexID=id;sha256=hash
        if owner.window.contentView !== split {
            let frame=owner.window.contentView?.bounds ?? NSRect(x:0,y:0,width:1280,height:850)
            owner.webView.removeFromSuperview();split.frame=frame;split.addArrangedSubview(pane);split.addArrangedSubview(owner.webView);owner.window.contentView=split
            owner.webView.autoresizingMask=[.width,.height];owner.window.minSize=NSSize(width:1200,height:620)
            if owner.window.frame.width<1200 {var f=owner.window.frame;f.size.width=1200;owner.window.setFrame(f,display:true)}
            split.setPosition(430,ofDividerAt:0)
        }
        viewer.document=document;viewer.go(to:target);loading=false;pageChanged()
    }
    func pageChanged(){guard !loading,let doc=viewer.document,let page=viewer.currentPage else{return};let n=doc.index(for:page)+1;label.stringValue="物理第\(n) / \(doc.pageCount)页";let args=owner?.jsonString(["id":indexID,"page":n]) ?? "{}"
        owner?.webView.evaluateJavaScript("(()=>{const p=\(args);if(typeof pdfPageChanged28==='function')pdfPageChanged28(p.id,p.page)})()",completionHandler:nil)
    }
    @objc func previousPage(){viewer.goToPreviousPage(nil)}
    @objc func nextPage(){viewer.goToNextPage(nil)}
    @objc func closePane(){guard let owner else{return};owner.webView.removeFromSuperview();pane.removeFromSuperview();owner.window.contentView=owner.webView;owner.webView.autoresizingMask=[.width,.height];owner.window.minSize=NSSize(width:880,height:620)}
    func selection()throws->[String:Any]{
        guard let doc=viewer.document,let selection=viewer.currentSelection,let text=selection.string,!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,text.utf8.count<=2*1024*1024 else{throw NSError(domain:"KongScholar",code:28,userInfo:[NSLocalizedDescriptionKey:"请在并排原PDF中选择文字；扫描页可使用手工摘录与OCR。"])}
        let pages=selection.pages.sorted{doc.index(for:$0)<doc.index(for:$1)};guard !pages.isEmpty,pages.count<=100 else{throw ScholarStoreError.invalidData}
        let rows=try pages.map{page -> [String:Any] in
            let box=page.bounds(for:.cropBox),rect=selection.bounds(for:page).intersection(box);guard box.width>0,box.height>0,!rect.isNull,rect.width>0,rect.height>0 else{throw ScholarStoreError.invalidData}
            // PDF coordinates are bottom-up; saved regions use top-left origin, matching the OCR image view.
            let region=[(rect.minX-box.minX)/box.width,(box.maxY-rect.maxY)/box.height,rect.width/box.width,rect.height/box.height].map{max(0,min(1,Double($0)))}
            return["page":doc.index(for:page)+1,"region":region]
        }
        return["indexID":indexID,"sha256":sha256,"text":text,"pages":rows]
    }
}
extension AppDelegate {
    func materialPrompt28(_ prompt:String,text:String?,completion:@escaping(String?)->Void)->Bool{
        guard ["KONGSCHOLAR_PDF_DOCK","KONGSCHOLAR_PDF_SELECTION"].contains(prompt) else{return false}
        do{if prompt=="KONGSCHOLAR_PDF_SELECTION"{guard let dock=pdfDock28,window.contentView === dock.split else{throw ScholarStoreError.invalidData};completion(jsonString(try dock.selection()));return true}
            let bytes=Data((text ?? "{}").utf8);guard bytes.count<=2*1024*1024,let p=try JSONSerialization.jsonObject(with:bytes) as? [String:Any],let id=p["id"] as? String,let hash=p["sha256"] as? String,let n=p["page"] as? Int,n>=1 else{throw ScholarStoreError.invalidData}
            let(_,data)=try indexedPDF(p);guard let doc=PDFDocument(data:data),doc.page(at:n-1) != nil else{throw ScholarStoreError.invalidData}
            if pdfDock28==nil{pdfDock28=PDFDock28(owner:self)};pdfDock28?.show(document:doc,id:id,hash:hash,page:n);completion(jsonString(["opened":true,"page":n]))
        }catch{completion("error:"+error.localizedDescription)};return true
    }
}
