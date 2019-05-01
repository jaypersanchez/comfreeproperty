//Person constructor - ES5
function PersonES5(name, age, dob) {
    this.name = name;
    this.age = age;
    this.birthday = new Date(dob);
    /*this.calculateAge = function() {
        const diff = Date.now() - this.birthday.getTime();
        const ageDate = new Date(diff);
        return Math.abs(ageDate.getUTCFullYear() - 1972);
    }*/

}

PersonES5.prototype.calculateAge = function() {
    const diff = Date.now() - this.birthday.getTime();
    const ageDate = new Date(diff);
    return Math.abs(ageDate.getUTCFullYear() - 1972);
}

const brad = new PersonES5('Brad', 46, '1-14-2972');
console.log(brad.calculateAge());

//String versus String object
const name1 = 'Jay';
const name2 = new String('Jay');
//this will output string 'Jay'
console.log(name1); 
//this will output the object of the string: [String: 'Jay'] that you can manipulate and itirate over
console.log(name2); 
//you can dynamically add an object in the name2 object
name2.foo = 'bar';
//this will output: { [String: 'Jay'] foo: 'bar' }
console.log(name2);
console.log(typeof name1);
console.log(typeof name2);
//=== is compare to a string data type where name1 is just a string
if(name1==='Jay') {
    console.log('Yes');
}
else {
    console.log('No');
}
//but it won't work when comparing values to an object.  Use == instead
if(name2 === 'Jay') {
    console.log('Yes');
} else {
    console.log('N0');
}