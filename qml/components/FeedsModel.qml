import QtQuick 2.12
import QtQuick.XmlListModel 2.12
import QtQml.Models 2.2

ListModel {
	id:feedModel
	dynamicRoles:true
	property var sortOrder: appSettings.mainFeedSortAsc;
    property bool sorting: false;
	
	property var specialSort: {
		'updated' : function(itm) {return Date.parse(itm);}
	};

	onSortOrderChanged: sort();
	
	function sort() {
		if (DEBUG_MODE) console.log("Sorting...")
        let mins = false;
        let maxs = false;
        for(let fm=0; fm < feedModel.count;fm++) {
            var val = feedModel.getValue(feedModel.get(fm));
			if ( mins == false || val !== false && val < mins ) {
				mins = val;
			}
			if ( maxs == false ||  maxs < val ) {
				maxs = val;
			}
		}
        let sorted = [];
		sorted.length = feedModel.count;
		if(maxs - mins == 0 ) {
			return ;
		}
        let factor =  feedModel.count / (maxs - mins);
        for(let fm_=0; fm_ < feedModel.count;fm_++) {
            let value = JSON.parse(JSON.stringify(feedModel.get(fm_)));;
            let val = feedModel.getValue(value);
            let eIdx = val !== false ? parseInt((val - mins) * factor) : 0;
			if(isNaN(eIdx)) {
				eIdx = 0;
			}
			if(sorted[eIdx]) {
				while( sorted[eIdx] ) {
                    if (DEBUG_MODE) console.log(eIdx,fm_,val);
					if( val < feedModel.getValue(sorted[eIdx]) ) {
						var tmp = sorted[eIdx];
						sorted[eIdx] = value;
						val = feedModel.getValue(tmp);
						value = tmp;
					}
					eIdx++;
				}
				sorted[eIdx] = value;
			} else {
				sorted[eIdx] = value;
			}
		}
		
        let inIdx = sortOrder == Qt.AscendingOrder ? 0 : feedModel.count;
		feedModel.clear();
        for(let idx=sortOrder == Qt.AscendingOrder ? 0 : sorted.length;
			sortOrder == Qt.AscendingOrder  && idx < sorted.length || sortOrder !== Qt.AscendingOrder  && idx > 0  ; 
			idx+= sortOrder == Qt.AscendingOrder ? 1 : -1) {
			if(sorted[idx]) {
				feedModel.append(sorted[idx]);
				inIdx += sortOrder == Qt.AscendingOrder ? 1 : -1;
			}
		}
		if (DEBUG_MODE) console.log("Done Sorting.")
	}
	// true if a is less then b
	function lessThen(a,b) {
		return 	a == undefined || a[appSettings.mainFeedSortField] == undefined || //does 'a' even exists?
				(b[appSettings.mainFeedSortField] !== undefined  && ( //well if it does it can't be less then undefined...
				( specialSort[appSettings.mainFeedSortField] && specialSort[appSettings.mainFeedSortField](a[appSettings.mainFeedSortField]) < specialSort[appSettings.mainFeedSortField](b[appSettings.mainFeedSortField]) ) //do we have a special handling for the selected field?
				||
				(specialSort[appSettings.mainFeedSortField] == undefined && a[appSettings.mainFeedSortField] < b[appSettings.mainFeedSortField] ) ) );// or do we just sort it by the string value?
	}
	
	function getValue(i) {
		if(i == undefined || i[appSettings.mainFeedSortField] == undefined ) {
			return false;
		}
		if ( specialSort[appSettings.mainFeedSortField] ) {//do we have a special handleing for the selected field? 
			return specialSort[appSettings.mainFeedSortField](i[appSettings.mainFeedSortField]) ;
		}
		
		return i[appSettings.mainFeedSortField];
	}
	
	Component.onCompleted:sort();
}



