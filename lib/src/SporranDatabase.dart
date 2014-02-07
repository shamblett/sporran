/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 * 
 * 
 * A Sporran database comprises of a Wilt object and a Lawndart object in tandem, both sharing the
 * same database name. This allows Sporran to have multiple databases instantiated at any time keyed
 * by database name 
 */

part of sporran;

class _SporranDatabase {
  
  /**
   * The Wilt database
   */
  Wilt _wilt;
  Wilt get wilt => _wilt;
  
  /**
   * The Lawndart database
   */
  Store _lawndart;
  Store get lawndart => _lawndart;
  
  String _dbName;
  String get dbName => _dbName;
  
  /**
   * Construction, for Wilt we need URL and authentication parameters.
   * For LawnDart only the database name, the store name is fixed by Sporran
   */
  _SporranDatabase(this._dbName,
                  String hostName,
                  [String port = "5984",
                   String scheme = "http://",
                   String userName = null,
                   String password = null]) {
    
    
    /**
     * Instantiate a Store object
     */
    _lawndart = new Store(this._dbName,
                          "Sporran");
    _lawndart.open()
      .then((_) => _lawndart.nuke());
      
    /**
     * Instantiate a Wilt object
     */
    _wilt = new Wilt(hostName,
                     port,
                     scheme);
    
    if ( userName != null ) {
      
      _wilt.login(userName,
                  password);
    }
    
    /**
     * If the CouchDb database does not exist create it.
     */
    
    var createCompleter = ((_) {
      
      
      JsonObject res = _wilt.completionResponse;
      if ( !res.error ) {
      
        _wilt.db = _dbName;
        
      } else {
        
        throw new SporranException("Initialisation Failure - Wilt cannot create the database");
        
      }
      
      /**
       * TODO start change notifications here
       */
      
    });
    
    var allCompleter = ((_) {
      
      JsonObject res = _wilt.completionResponse;
      if ( !res.error ) {
        
        JsonObject successResponse = res.jsonCouchResponse;
        if ( !successResponse.contains(_dbName))
          
          _wilt.clientCompletion = createCompleter;
          _wilt.createDatabase(_dbName);
          
        
      } else {
        
        _wilt.db = _dbName;
        
      }
      
    });
    
    _wilt.clientCompletion = allCompleter;
    _wilt.getAllDbs();
      
  }
    
}