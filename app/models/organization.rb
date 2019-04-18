class Organization < ApplicationRecord
    after_create :set_map_info
    def self.load_from_ustc
        require 'ustc'
        organizations = USTC.get_all
        organizations.each do |org|
            o = Organization.find_or_create_by name: org['name'], domain: org['hostname']
            o.update_attributes ipv4: org['ipv4'],
                httpsv4: org['httpsv4'], http2v4: org['http2v4'], httpv4: org['httpv4'],
                ipv6: org['ipv6'], httpsv6: org['httpsv6'], http2v6: org['http2v6'], httpv6: org['httpv6'],
                score: org['score']
        end
    end

    def self.load_from_json
        json_dir = Rails.root.join('db/organizations')
        host_black_list = ["baike.baidu.com"]
        Dir.foreach(json_dir) do |x| 
            if File.file?(json_dir.join(x))
                categories = JSON.parse File.read(json_dir.join(x))
                categories.each_pair do |cate, orgs|
                    orgs.each_pair do |name, url|
                        url = url.strip
                        org_name = name.delete_suffix("（民办）")
                        founder = "民办" unless org_name.eql?(name)
                        org_name = org_name.delete_suffix("（百科）")
                        p org_name
                        o = Organization.find_by name: org_name
                        o = Organization.new name: org_name if o.nil?
                        o.province = File.basename(x, ".json")
                        uri = URI.parse url
                        unless host_black_list.include?(uri.host)
                            o.domain= uri.host
                            o.category= cate
                            o.url= url
                        end
                        o.save
                    end
                end
            end
        end
    end

    def set_map_info
        if self.longitude.blank? or self.latitude.blank?
            begin
                map_data =  BaiduMap.search_map self.name, self.province
                self.update_attributes latitude: map_data['location']['lat'],
                longitude: map_data['location']['lng'], address: map_data['address'],
                province: map_data['province'], city: map_data['city'], area: map_data['area'],
                telephone: map_data['telephone']
            rescue => e
                p "Error in set_map_info"
                p e.message
            end
        end
    end

    def check_ipv4
        #cmd = "curl -L -4 #{serlf.url}"
        #rs = system(cmd)

    end

    def check_ipv6
        #cmd = "curl -L -I -6 #{self.url}"
        require 'resolv'
        # 1. dns
        begin
            resource = Resolv::DNS.new.getresource(self.domain,Resolv::DNS::Resource::IN::AAAA)
            self.ipv6 = true unless resource.nil?
        rescue => e
            p "IPv6 DNS lookup of #{self.domain} failed"
            return
        end
        # 2. http
        # 3. https
    end
end
