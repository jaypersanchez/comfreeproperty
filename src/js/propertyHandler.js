var listOfPropertiesForSale = new Array();

class Property {
    constructor(_header_banner, _property_address, _property_feature, _listing_price) {
        this.id_datestamp = "activeoffer-" + Math.floor(Math.random()*1972);
        this.header_banner = _header_banner;
        this.property_address = _property_address;
        this.property_feature = _property_feature;
        this.listing_price = _listing_price;
        this.hasOffer = false;
    }
}

class PropertyListingUI {

    addPropertyToList(property) {
        const list = document.getElementById('property-list');
        // Create tr element
        const row = document.createElement('tr');
        // Insert cols
        row.innerHTML = `
            <td>${property.header_banner}</td>
            <td>${property.property_address}</td>
            <td>${property.property_feature}</td>
            <td><a href="activeOffers.html?id=${property.id_datestamp}&banner=${property.header_banner}&address=${property.property_address}&feature=${property.property_feature}&price=${property.listing_price}" id=${property.id_datestamp}>${property.listing_price}</a></td>
            <td><a href="#" class="delete">X<a></td>
            `;
  
        list.appendChild(row);
        listOfPropertiesForSale.push(property);
        localStorage.setItem(property.id_datestamp, JSON.stringify(property));
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
        const form = document.querySelector('#property-form');
        // Insert alert
        container.insertBefore(div, form);

        // Timeout after 3 sec
        setTimeout(function() {
        document.querySelector('.alert').remove();
        }, 5000);
    }

    removeFromList(target) {
        if(target.className === 'delete') {
            target.parentElement.parentElement.remove();
        }
    }

    clearFields() {
        document.getElementById('headerbanner').value = '';
        document.getElementById('address').value = '';
        document.getElementById('features').value = '';
        document.getElementById('listing_price').value = '';
    }

}

class StoreProperties {
    static getProperties() {
        let properties;
        if(window.localStorage.getItem('properties') === null) {
            properties = [];
        }
        else {
            properties = JSON.parse(window.localStorage.getItem('properties'));
        }
        return properties;
    }

    static displayProperties() {
        const properties = StoreProperties.getProperties();
        properties.forEach(function(property){
            // Instantiate UI
            const propertyListingUI = new PropertyListingUI(property)

            // Add book to UI
            propertyListingUI.addPropertyToList(property);
        });
    }

    static addProperty(_property) {
        const properties = StoreProperties.getProperties();
        properties.push(_property);
        window.localStorage.setItem('properties', JSON.stringify(properties));
    }

    static removeProperty(id) {
        const properties = StoreProperties.getProperties();
        properties.forEach(function(property, index) {
            if(property.id_datestamp = id) {
                properties.splice(index, 1);
            }
        });
    }
}


//DOM event
document.addEventListener('DOMContentLoaded', StoreProperties.displayProperties);

// Event Listener for add property
    document.getElementById('properties-form').addEventListener('submit', function(e){
        
        // Get form values
        const headerbanner = document.getElementById('headerbanner').value,
            address = document.getElementById('address').value,
            features = document.getElementById('features').value
            price = document.getElementById('listing_price').value
            

        // Instantiate book
        const property = new Property(headerbanner, address, features, price);

        // Instantiate UI
        const propertyListingUI = new PropertyListingUI(property);

        //console.log(propertyListingUI);

        // Validate
        if(headerbanner === '' || address === '' || features === '') {
            // Error alert
            propertyListingUI.showAlert('Please fill in all fields', 'error');
        } 
        else {
            // Add book to list
            propertyListingUI.addPropertyToList(property);
            //add to localstorage
            StoreProperties.addProperty(property);

            // Show success
            propertyListingUI.showAlert('Property Added!', 'success');
  
            // Clear fields
            propertyListingUI.clearFields();
        }

        e.preventDefault();
    });

    
    // Event Listener for delete
    document.getElementById('property-list').addEventListener('click', function(e){
           var source = e.srcElement || e.originalTarget;
           //alert(this.id);
           //alert(source.id);
           if(source.id.includes("activeoffer")) {
               //alert("forward");
           }
           else {
                //alert("event source: " + source.id);
                // Instantiate UI
                const propertyListingUI = new PropertyListingUI();

                // remove from listing
                propertyListingUI.removeFromList(e.target);
                //remove from localStorage
                StoreProperties.removeProperty(e.target.parentElement.previousElementSibling.textContent);
                // Show message
                propertyListingUI.showAlert('Property Removed!', 'success');
        
                e.preventDefault();
           }
           
    });