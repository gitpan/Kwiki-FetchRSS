use inc::Module::Install;

name('Kwiki-FetchRSS');
abstract('WAFL Plugin To Fetch an RSS Feed');
license('perl');
version_from('lib/Kwiki/FetchRSS.pm');

requires('Cache::FileCache');
requires('LWP::UserAgent');
requires('XML::RSS');


check_nmake();

&WriteAll();
