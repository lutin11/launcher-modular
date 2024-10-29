import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.Controls 2.2 as QControls

ListItem {
	height: visible ?  __listItemLayout.height + units.gu(1) : 0;

	ListItemLayout {
		id:__listItemLayout
		title.text:titleText
		title.color: launchermodular.settings.textColor
		title.wrapMode:Text.WordWrap
		title.textFormat:Text.RichText
		subtitle.text:{return (new Date(updated)).toDateString()}
		subtitle.color: "#AEA79F"
		summary.text:description.replace(/<[^>]+>/g,'')
		summary.textFormat:Text.PlainText
		summary.wrapMode:Text.WordWrap
		summary.color: "#AEA79F"

		Image {
			id:imgIcon
			height:units.gu(3)
			width:height
			cache:true
			sourceSize.width:width
			SlotsLayout.position: SlotsLayout.Trailing;
			source:imageUrl ? imageUrl : (chImageUrl ? chImageUrl : "" )
			asynchronous:true
		}

		Label {
			id:txtIcon
			height:2
			width: height * 1.6
			text: channel
			color: "#ffffff"

			horizontalAlignment: Text.AlignHCenter
			minimumPixelSize:units.gu(1);
			wrapMode:Text.WordWrap
			fontSizeMode: Text.Fit
			SlotsLayout.position: SlotsLayout.Trailing;
		}
		states : [
			State {
				name:"no_image_state"
				when: !imageUrl &&  !chImageUrl
				PropertyChanges { target:imgIcon; height:0;}
				PropertyChanges { target:txtIcon; height:units.gu(3);}
			},
			State {
				name:"has_image_state"
				when: imageUrl ||  chImageUrl
				PropertyChanges { target:imgIcon; height:units.gu(3);}
				PropertyChanges { target:txtIcon; height:0;}
			}
		]
	}
}

