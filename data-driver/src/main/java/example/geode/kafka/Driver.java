/*
 * Copyright  2018 Charlie Black
 *
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
 *
 */

package example.geode.kafka;

import io.codearte.jfairy.Fairy;
import io.codearte.jfairy.producer.person.Person;
import org.apache.geode.cache.GemFireCache;
import org.apache.geode.cache.Region;
import org.apache.geode.cache.client.ClientCache;
import org.apache.geode.cache.client.ClientRegionShortcut;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Profile;
import org.springframework.data.gemfire.config.annotation.ClientCacheApplication;
import org.springframework.data.gemfire.config.annotation.EnablePdx;
import org.springframework.data.gemfire.config.annotation.EnableSecurity;
import org.springframework.data.gemfire.mapping.MappingPdxSerializer;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.annotation.Resource;
import java.util.UUID;

@RestController
@Profile("dev")
@ClientCacheApplication(name = "Kafka", logLevel = "error")
@EnablePdx(serializerBeanName = "pdxSerializer")
@EnableSecurity
@SpringBootApplication
public class Driver {

    @Resource
    Region<String, Customer> customerRegion;

    @Bean
    MappingPdxSerializer pdxSerializer() {
        MappingPdxSerializer pdxSerializer = new MappingPdxSerializer();
        pdxSerializer.setIncludeTypeFilters(type -> Customer.class.isAssignableFrom(type));
        return pdxSerializer;
    }

    @Bean
    Region<String, Customer> customerRegion(GemFireCache gemfireCache) {
        return ((ClientCache)gemfireCache).<String, Customer>createClientRegionFactory(ClientRegionShortcut.PROXY).create("test");
    }

    @RequestMapping("/createCustomers")
    public boolean createCustomers(int count) {
        Fairy fairy = Fairy.create();
        for (int i = 0; i < count; i++) {
            Person person = fairy.person();
            Customer customer = Customer.builder()
                    .firstName(person.getFirstName())
                    .middleName(person.getMiddleName())
                    .lastName(person.getLastName())
                    .email(person.getEmail())
                    .username(person.getUsername())
                    .passportNumber(person.getPassportNumber())
                    .password(person.getPassword())
                    .telephoneNumber(person.getTelephoneNumber())
                    .dateOfBirth(person.getDateOfBirth().toString())
                    .age(person.getAge())
                    .companyEmail(person.getCompanyEmail())
                    .nationalIdentificationNumber(person.getNationalIdentificationNumber())
                    .nationalIdentityCardNumber(person.getNationalIdentityCardNumber())
                    .passportNumber(person.getPassportNumber())
                    .guid(UUID.randomUUID().toString()).build();
            customerRegion.put(customer.getGuid(), customer);
        }
        return true;
    }

    public static void main(String[] args) {
        SpringApplication.run(Driver.class, args);
    }
}
