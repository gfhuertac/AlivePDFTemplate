AlivePDF is based on FPDF, a PHP PDF library, which is quite easy to extend. One of the extension, FPDi, allows you to import existing PDF files into a new PDF as a template. I decided to port this extension into AlivePDF, and it took me a couple of days to do so.
Please be aware that this is a beta release. I tested with few cases only. It is licensed under the Apache 2.0 license, so you can use it and modify it the way you want.

To use it, you can use the following example as a reference, or check the FPDi website for more examples.

//Must create a new PDFi instance (not PDF)
	var myPDF : PDFi = new PDFi ( Orientation.PORTRAIT, Unit.MM );

// Import a file!!!! Just set the source file to an existing PDF
	var pagecount:Number = myPDF.setSourceFile(File.desktopDirectory.nativePath + File.separator + "FPDF_TPL-Manual-1.1.pdf" );

// Import a page. The first argument is the page number, the second the way it will be imported
	var tplidx:Number = myPDF.importPage(1, '/MediaBox'); 

//This is important, you MUST add a page first!!!!
	myPDF.addPage();

//Use the template in the current page
	myPDF.useTemplate(tplidx, 10, 10, 90);

// This is not part of the original PDF. Just a test ^^
	var myFont:IFont = new CoreFont ( FontFamily.HELVETICA_BOLD );
	myPDF.setFont( myFont );
	myPDF.setFontSize ( 18 );
	myPDF.setXY( 10, 40 );
	myPDF.addMultiCell ( 300, 1, "This is my PDF Headline" );

//Save the file
	var f : FileStream = new FileStream();
	var file : File = File.desktopDirectory.resolvePath("MyPDFi.pdf");
	f.open( file, FileMode.WRITE);
	var bytes : ByteArray = myPDF.save(Method.LOCAL);
	f.writeBytes(bytes);
	f.close();  

