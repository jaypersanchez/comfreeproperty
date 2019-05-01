 var listOfActiveOffers = new Array();

class Offers {
    constructor(_id, _header_banner, _property_address, _property_feature, _listed_price, _offered_price) {
        this.id = _id; //from property ID
        this.id_offer = "activeoffer-" + Math.floor(Math.random()*1972); 
        this.header_banner = _header_banner;
        this.property_address = _property_address;
        this.property_feature = _property_feature;
        this.listing_price = _listed_price;
        this.offered_price = _offered_price;
        this.hasOffer = false;
    }
}

class ActiveOfferListingUI {

    addPropertyToActiveOfferList(offer) {
        const list = document.getElementById('property-list');
        // Create tr element
        const row = document.createElement('tr');
        // Insert cols
        row.innerHTML = `
            <td>${offer.id} - ${offer.id_offer}</td>
            <td>${offer.property_address}</td>
            <td>${offer.listed_price}</td>
            <td><a href="activeEscrows.html?id=${offer.id_offer}" id=${offer.id_offer}>${offer.offered_price}</a></td>
            <td><a href="#" class="delete">Decline<a></td>
            `;
        //alert("UInew offer: " + offer.id + ":" + offer.id_offer + ":" + offer.property_address + ":" + offer.listed_price + ":" + offer.offered_price );
        list.appendChild(row);
        //listOfActiveOffers.push(offer);
        //window.localStorage.setItem(offer.id_offer, JSON.stringify(offer));
    }

    showAlert(message, className) {
        // Create div
        const div = document.createElement('div');
        // Add classes
        div.className = `alert ${className}`;
        // Add text
        div.appendChild(document.createTextNode(message));
        // Get parent
        const container = document.querySelector('.container');
        // Get form
        const form = document.querySelector('#book-form');
        // Insert alert
        container.insertBefore(div, form);

        // Timeout after 3 sec
        setTimeout(function(){
        document.querySelector('.alert').remove();
        }, 3000);
    }

    removeFromList(target) {
        if(target.className === 'delete') {
            target.parentElement.parentElement.remove();
        }
    }

    clearFields() {
        document.getElementById('property_id').value = '';
        document.getElementById('headerbanner').value = '';
        document.getElementById('address').value = '';
        document.getElementById('features').value = '';
        document.getElementById('listing_price').value = '';
        document.getElementById('offer_price').value = '';
    }

}

class StoreProperties {
    
    static getActiveOffers() {
        let activeoffers;
        if(window.localStorage.getItem('activeoffers') === null) {
            activeoffers = [];
            
        }
        else {
            activeoffers = JSON.parse(window.localStorage.getItem('activeoffers'));
            
        }
        //alert("lenght: " + activeoffers.length);
        return activeoffers;
    }

    static addPropertyToActiveOfferList(_offer) {
        const activeoffers = StoreProperties.getActiveOffers();
        activeoffers.push(_offer);
        window.localStorage.setItem('activeoffers', JSON.stringify(activeoffers));
    }

    static displayActiveOffers() {
        const activeoffers = StoreProperties.getActiveOffers();
        activeoffers.forEach(function(offer){
                // Instantiate UI
                const activeOfferListingUI = new ActiveOfferListingUI();

                // Add active offer
                activeOfferListingUI.addPropertyToActiveOfferList(offer);
        });
        
    }

    static getActiveOffersById(_property_id) {
        /*const activeoffers = StoreProperties.getActiveOffers();
        activeoffers.forEach(function(activeoffer){
            //alert("ID: " + property.id_datestamp);
            if(activeoffer.id === _property_id) {
                document.getElementById("property_id").value = property.id_datestamp;
                document.getElementById('headerbanner').value = property.header_banner;
                document.getElementById('address').value = property.property_address;
                document.getElementById('features').value = property.property_feature;
                document.getElementById('listing_price').value = property.listing_price;
            }
        });*/
    }
}//StoreProperties

/*
*   Event listeners
*/
//DOM event
//document.addEventListener('DOMContentLoaded', StoreProperties.displayProperties);

document.addEventListener('DOMContentLoaded', function(e) {
    var urlParams = new URLSearchParams(window.location.search);
    /*
    * If POST header is passed an 'id' field, display property data on form in order for user to enter an offered price
    */
    if( urlParams.has("id") ) {
        //properties = JSON.parse(window.localStorage.getItem('properties'));
        //alert(urlParams.get('id'));
        //properties.forEach(function(property) {
            //if(property.id_datestamp === urlParams.get('id')) {
                document.getElementById('property_id').value = urlParams.get('id');
                document.getElementById('headerbanner').value = urlParams.get('banner');
                document.getElementById('address').value = urlParams.get('address');
                document.getElementById('features').value = urlParams.get('feature');
                document.getElementById('listing_price').value = urlParams.get('price');
            //}
        //});
        
    }
    else {
        //StoreProperties.displayActiveOffers();
    }

    document.getElementById('properties-form').addEventListener('submit', function(e){
        //capture source of button
        var source = e.srcElement || e.originalTarget;
        // Get form values
        const property_id = document.getElementById('property_id').value,
            headerbanner = document.getElementById('headerbanner').value,
            address = document.getElementById('address').value,
            features = document.getElementById('features').value
            price = document.getElementById('listing_price').value
            offer_price = document.getElementById('offer_price').value
            
            // Instantiate book
            const activeOfferListingUI = new ActiveOfferListingUI();
            // Validate
            if(offer_price === '') {
                // Error alert
                activeOfferListingUI.showAlert('Please fill in all fields', 'error');
            }
            else {
                offer = new Offers(property_id, headerbanner, address, features, price, offer_price);
                window.localStorage.setItem('activeoffers', JSON.stringify(offer));
                
                activeOfferListingUI.addPropertyToActiveOfferList(offer);
                
                //add to storage
                //StoreProperties.addPropertyToActiveOfferList(offer);
                
                // Show success
                activeOfferListingUI.showAlert('Offer Added!', 'success');
    
                // Clear fields
                activeOfferListingUI.clearFields();
            }
            
            e.preventDefault();
        
    });

    document.getElementById('property-list').addEventListener('click', function(e){
        //capture source of click
        var source = e.srcElement || e.originalTarget;
        alert("click source: " + source.id);
    });

});
