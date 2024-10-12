import { LightningElement, api, track, wire } from 'lwc';
import getRec from "@salesforce/apex/GoogleDriveController.initGDWidget";
import addNewFolder from "@salesforce/apex/GoogleDriveController.createFolder";
import addNewFile from "@salesforce/apex/GoogleDriveController.uploadFile";

export default class GoogleDriveWidget extends LightningElement {
    @api recordId;  // Opportunity Id is passed automatically by Lightning record page

    // Reactive property to hold the opportunity data
    opportunity;
    showNewFolderButton = false;
    authError;
    message;
    files;

    @wire(getRec, { recordId: '$recordId'})
    wiredRecord({ error, data }) {
        //console.log(data);
        if(data){
            console.log('', JSON.stringify(data));
            if (data.isFolderCreated) {
                this.showNewFolderButton = false;
            }else{
                this.showNewFolderButton = true;
            }
            if (data.isTokenExpired) {
                this.authError = "Google Drive Access Token has been expired. Please get the token by clickling below URL and then try again!";
            }
            if(data.files) {
                this.files = data.files;
            }

        }
    }

    async newFolderRequest(event){
        console.log(this.opportunity, this.recordId);
        const response = await addNewFolder({recordId: this.recordId});
        console.log(response, 'gd___');
        if(response === "ACCESS_TOKEN_EXPIRED"){
            this.authError = "Google Drive Access Token has been expired. Please get the token by clickling below URL and then try again!";
        }else{
            this.message = response;
            this.showNewFolderButton = false;
        }
    }

    get acceptedFormats() {
        return ['.pdf', '.png'];
    }

    async handleUploadFinished(event) {
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        console.log('No. of files uploaded : ' + JSON.stringify(uploadedFiles));
        const response = await addNewFile({recordId: this.recordId, fileDetails: JSON.stringify(uploadedFiles)});
    }
    preview(event){
        
        const label = event.target.id.split('-');
        
        var url = 'https://drive.google.com/file/d/'+label[0]+'/view';
        window.open(url, '_blank');
    }

}