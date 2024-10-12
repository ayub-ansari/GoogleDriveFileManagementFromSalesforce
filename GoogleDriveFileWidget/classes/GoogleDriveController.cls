/*
 * Copyright (c) 2024, Ayub Ansari/ayub.salsforce@gmail.com/Tenetizer Technologies
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 * - Neither the name of the tenetizer.com, inc nor the names of its contributors
 *      may be used to endorse or promote products derived from this software without
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
public class GoogleDriveController {

    public void init(){
        String code = System.currentPagereference().getParameters().get('code');
        String userId = System.currentPagereference().getParameters().get('state');
        googleAuth(code);
    }
    
    public void googleAuth(String code) {
        GoogleAuth__c app = GoogleAuth__c.getInstance();
        String cid = app.ClientId__c;
        String sec = app.ClientSecret__c;
        String redirecurl= app.RedirectURI__c; 
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        String requestUrl = '';
        Integer len = 0;
        requestUrl = requestUrl + 'https://www.googleapis.com/oauth2/v4/token';
        requestUrl = requestUrl + '?code=' + EncodingUtil.urlEncode(code, 'UTF-8');
        requestUrl = requestUrl + '&redirect_uri=' + EncodingUtil.urlEncode(redirecurl, 'UTF-8');
        requestUrl = requestUrl + '&client_id=' + EncodingUtil.urlEncode(cid, 'UTF-8');
        requestUrl = requestUrl + '&client_secret=' + EncodingUtil.urlEncode(sec, 'UTF-8');
        requestUrl = requestUrl + '&grant_type=' + 'authorization_code';
        request.setEndpoint(requestUrl);
        request.setMethod('POST');
        request.setHeader('content-type', 'application/x-www-form-urlencoded');
        request.setHeader('Content-length', '0');
        String requestBody = '';
        if(!Test.isRunningTest()){
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                System.Debug('Auth=======' + response.getBody());
               
                GAuthDetail g = new GAuthDetail();
                g = (GAuthDetail)System.JSON.deserialize(response.getBody(), GAuthDetail.class);  
                
                app.Token__c = g.access_token;
                //app.Refresh_Token__c = gAuthDetail.refresh_token;
                app.Expire_At__c = DateTime.Now().addSeconds(Integer.ValueOf(g.expires_in));
                upsert app;
                //Cache.Session.put('gToken', g.access_token, g.expires_in);
                
            }else{
                System.Debug('ErrorAuth=======' + response.getBody());
            }
        }
    }
    
    
    
    public class GAuthDetail {
        public string access_token;
        public integer expires_in;
    }
    
    
    //____LWC_____CODE_BELOW____________
    
    @AuraEnabled(cacheable=true)
    public static GDriveData initGDWidget(String recordId){
        GDriveData gd = new GDriveData();
        List<SObject> records = getRecord(recordId);
        String token = getToken();
        if(token == null) gd.isTokenExpired = true;
        if(!records.isEmpty() && (String)records[0].get('FolderId__c') != null) gd.isFolderCreated = true;
        if(!gd.isTokenExpired && gd.isFolderCreated) {
           gd.files = getFilesFromGDrive(token, (String)records[0].get('FolderId__c'));
           system.debug(gd.files+'______');
           gd.message = 'debug';
        }
        
        return gd;
    }
    
    @AuraEnabled
    public static String createFolder(String recordId){
        String token = getToken();
        if(token == null) return 'ACCESS_TOKEN_EXPIRED';
        String response = createFolderGDrive(recordId, token);
        return response;
    }
    @AuraEnabled
    public static String uploadFile(String recordId, String fileDetails){
         GDriveData gd = new GDriveData();
        String token = getToken();
        if(token == null) gd.isTokenExpired = true;
        String response = uploadFileGDrive(recordId, token, fileDetails);
        return response;
    }
    
    
    public static String getToken(){
        GoogleAuth__c app = GoogleAuth__c.getInstance();
        if(app == null || app.Expire_At__c < Datetime.now()) return null;
        return app.Token__c;
    }
    public static String getSobjectTypeFromRecordId(String recordId) {
        return ((Id)recordId).getSObjectType().getDescribe().getName();
    }
    
    public static List<SObject> getRecord(String recordId){
        String obj = getSobjectTypeFromRecordId(recordId);
        String query = 'SELECT FolderId__c, Name FROM '+obj+' WHERE Id=\''+recordId+'\'';
        return Database.query(query);
    }
    
    public class GDriveData{
        @AuraEnabled
        public Boolean isTokenExpired{get;set;}
        @AuraEnabled
        public Boolean isFolderCreated {get;set;}
        @AuraEnabled
        public String message {get;set;}
        
        @AuraEnabled
        public List<Object> files {get;set;}
        
        public GDriveData(){
            this.isTokenExpired = false;
            this.isFolderCreated = false;
            this.files = new List<Object>();
        }
    }
    public class InputFile{
        @AuraEnabled
        public String name {get;set;}
        @AuraEnabled
        public String id {get;set;}
        @AuraEnabled
        public String kind {get;set;}
        @AuraEnabled
        public String documentId {get;set;}
        @AuraEnabled
        public String contentVersionId {get;set;}
        @AuraEnabled
        public String contentBodyId {get;set;}
        @AuraEnabled
        public String mimeType {get;set;}
    }
    
    public static List<Object> getFilesFromGDrive(String token, String folderId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://www.googleapis.com/drive/v3/files?q=\''+folderId+'\'+in+parents');
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer '+token);
        HTTPResponse res = http.send(request);
        system.debug(res.getBody());
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (List<Object>)responseMap.get('files');

    }

    public static String uploadFileGDrive(String recordId, String token, String fileDetails){
        List<SObject> record = getRecord(recordId);
        Set<String> cvId = new Set<String>();
        //[{"name":"gdlgo.png","documentId":"069GC00000OklTCYAZ","contentVersionId":"068GC00000PRHOnYAP","contentBodyId":"05TGC00002Bnajd2AB","mimeType":"image/png"}]
        List<InputFile> files = (List<InputFile>)System.JSON.deserialize(fileDetails, List<InputFile>.class); 
        for(InputFile f: files) cvId.add(f.contentVersionId);
        Map<Id, ContentVersion> cvmap = new Map<Id, ContentVersion>([SELECT VersionData FROM ContentVersion WHERE Id IN: cvId]);
        for(InputFile f: files){
            Blob data = [SELECT VersionData from ContentVersion where contentdocumentId='0692v00000LEdPNAA1'].VersionData;

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setHeader('Content-Type', 'multipart/related; boundary=foo_bar_baz');

            String boundary = '--foo_bar_baz';
            String body = boundary + '\n' +
                'Content-Type: application/json; charset=UTF-8\n\n' +
                '{ "name": "'+f.name+'", "parents": ["'+(String)record[0].get('FolderId__c')+'"] }\n' +
                boundary + '\n' +
                'Content-Type: '+f.mimeType+'\n'+
                'Content-Transfer-Encoding: base64\n\n' +
                 EncodingUtil.base64Encode(cvmap.get(f.contentVersionId).VersionData)+ '\n' + boundary + '--';
                 //(cvmap.get(f.contentVersionId).VersionData).tostring()+ '\n' + boundary + '--';
            system.debug(EncodingUtil.base64Encode(cvmap.get(f.contentVersionId).VersionData));
            req.setBody(body);

            Http http = new Http();
            HTTPResponse res = http.send(req);

            System.debug('Response: ' + req.getBody());
            
        }
        return 'success';
    }
    
    public static String createFolderGDrive(String recordId, String token) {
        List<SObject> record = getRecord(recordId);
        String gDriveFolderId = createFolderHttpCall((String)record[0].get('Name'), token);
        record[0].put('FolderId__c', gDriveFolderId);
        update record;
        return 'Folder created successfully.';
    }
    public static String createFolderHttpCall(String name, String token) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://www.googleapis.com/drive/v3/files');
        request.setMethod('POST');
        request.setHeader('content-type', 'application/json');
        request.setHeader('Content-length', '0');
        request.setHeader('Authorization', 'Bearer '+token);
        String requestBody = '{"name": "'+name+'","mimeType": "application/vnd.google-apps.folder"}';
        request.setBody(requestBody);
        HttpResponse response = http.send(request);
        system.debug(response.getBody());
        
        Folder f = (Folder)System.JSON.deserialize(response.getBody(), Folder.class);  
        return f.id;
    }

    public class Folder {

        public String kind;
        public String id;
        public String name;
        public String mimeType;

    }

}